###############################################################################
# modules/gke/main.tf
# Private GKE cluster on a Shared VPC. Zonal or regional via var.regional.
# REGULAR release channel + node auto-provisioning to back GKE Compute Classes.
###############################################################################

resource "google_container_cluster" "primary" {
  provider = google-beta

  project  = var.service_project_id
  name     = var.cluster_name
  location = local.location

  # Regional: spread over a slice() of discovered zones. Zonal: null (omitted).
  node_locations = local.node_locations

  # Use the Shared VPC from the host project (full network/subnet references).
  network    = var.network_id
  subnetwork = var.subnet_id

  # Remove the default node pool; we manage our own below.
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = var.deletion_protection

  # ---- Private cluster: no public node IPs ----
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # public control-plane endpoint, locked by authorized networks
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block

    master_global_access_config {
      enabled = true
    }
  }

  # Restrict who can reach the IP-based control plane.
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # DNS-based control-plane endpoint (IAM-gated, no IP allowlist needed).
  dynamic "control_plane_endpoints_config" {
    for_each = var.dns_endpoint_enabled ? [1] : []
    content {
      dns_endpoint_config {
        allow_external_traffic = var.dns_endpoint_allow_external_traffic
      }
    }
  }

  # ---- VPC-native: map secondary ranges from the Shared VPC subnet ----
  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # ---- Release channel + optional version floor ----
  # min_master_version is a MINIMUM: if the channel auto-upgrades above it there
  # is no perpetual diff (the provider suppresses when configured <= actual).
  # null => omitted => the channel's default version is used.
  release_channel {
    channel = var.release_channel
  }

  min_master_version = var.kubernetes_version

  # ---- Workload Identity ----
  workload_identity_config {
    workload_pool = "${var.service_project_id}.svc.id.goog"
  }

  # ---- Compute Classes support: node auto-provisioning (NAP) ----
  # Custom Compute Classes are defined as Kubernetes resources (see
  # compute-class.yaml) and provision nodes through NAP within these limits.
  # Spot vs on-demand for NAP nodes is chosen per-ComputeClass (priorities[].spot),
  # NOT here — the GKE API exposes no global "all NAP nodes are spot" toggle.
  cluster_autoscaling {
    enabled = true

    resource_limits {
      resource_type = "cpu"
      minimum       = var.nap_cpu_min
      maximum       = var.nap_cpu_max
    }
    resource_limits {
      resource_type = "memory"
      minimum       = var.nap_memory_min
      maximum       = var.nap_memory_max
    }

    auto_provisioning_defaults {
      service_account = var.node_service_account_email
      oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

      management {
        auto_repair  = true
        auto_upgrade = true
      }

      shielded_instance_config {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }
    }
  }

  # Security hardening.
  enable_shielded_nodes = true

  datapath_provider = "ADVANCED_DATAPATH" # Dataplane V2 (eBPF) for network policy

  # ---- Gateway API (preferred over legacy Ingress) ----
  # CHANNEL_STANDARD installs the GA Gateway API CRDs + GKE controller, enabling
  # gke-l7-* GatewayClasses. CHANNEL_DISABLED would remove them.
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  monitoring_config {
    # WORKLOADS monitoring was removed after GKE 1.24; Managed Prometheus
    # collects workload metrics on modern clusters instead.
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }

    # ---- Dataplane V2 observability (requires ADVANCED_DATAPATH above) ----
    # enable_metrics: Dataplane V2 metrics (pod/policy flow metrics to Cloud
    #   Monitoring). enable_relay: Dataplane V2 Observability flow-logging relay
    #   (Hubble), surfaced in the GKE "DPv2 observability" UI / `kubectl` flows.
    advanced_datapath_observability_config {
      enable_metrics = true
      enable_relay   = true
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  resource_labels = var.labels
}

# ---- Managed system node pool (baseline capacity; CCC handles burst) ----
# On-demand by design: runs system-critical components, never Spot.
resource "google_container_node_pool" "system" {
  provider = google-beta

  project  = var.service_project_id
  name     = "${var.cluster_name}-system" # e.g. it-prod-standard-system
  location = local.location
  cluster  = google_container_cluster.primary.name

  # Pin to a single zone when requested (in-place updatable; no recreate).
  # null => inherit the cluster's node_locations.
  node_locations = var.system_pool_single_zone ? [local.zones[0]] : null

  initial_node_count = 1

  # total_* pins the node count cluster-wide (not per-zone).
  # Equal min/max => exactly system_node_count nodes.
  autoscaling {
    total_min_node_count = var.system_node_count
    total_max_node_count = var.system_node_count
    location_policy      = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    disk_size_gb    = var.node_disk_size_gb
    disk_type       = var.node_disk_type
    service_account = var.node_service_account_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Hardened, private nodes.
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = var.labels
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# ---- Default Spot node pool (general/burst workloads) -----------------------
# Created WITH the cluster. Same hardening as the system pool but on Spot VMs.
# Critical/system components stay on the on-demand `system` pool above; burst
# and Compute-Class workloads run here (and on NAP-created Spot pools).
resource "google_container_node_pool" "default" {
  count    = var.default_pool_enabled ? 1 : 0
  provider = google-beta

  project  = var.service_project_id
  name     = "${var.cluster_name}-default" # e.g. it-prod-standard-default
  location = local.location
  cluster  = google_container_cluster.primary.name

  # null => inherit the cluster's node_locations (regional spreads across zones).
  node_locations = var.system_pool_single_zone ? [local.zones[0]] : null

  autoscaling {
    total_min_node_count = var.default_pool_min_nodes
    total_max_node_count = var.default_pool_max_nodes
    # ANY maximizes Spot obtainability: pull capacity from whichever zone has it.
    location_policy = "ANY"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    spot            = true # <-- Spot VMs (preemptible-successor; no max runtime)
    machine_type    = var.default_pool_machine_type
    disk_size_gb    = var.node_disk_size_gb
    disk_type       = var.node_disk_type
    service_account = var.node_service_account_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Hardened, private nodes (same baseline as the system pool).
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Optional taint so only Spot-tolerant workloads schedule here.
    dynamic "taint" {
      for_each = var.default_pool_taint ? [1] : []
      content {
        key    = "cloud.google.com/gke-spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    }

    labels = var.labels
  }

  # Surge-only upgrades keep capacity during rolls; Spot may still be reclaimed.
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

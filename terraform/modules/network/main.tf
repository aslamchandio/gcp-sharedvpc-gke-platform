###############################################################################
# modules/network/main.tf  (HOST PROJECT — project-a)
# Shared VPC, two regular subnets (via slice + for_each, multi-region),
# proxy-only subnet, Cloud Router + NAT, firewall.
###############################################################################

# ---- Enable Shared VPC on the host project and attach the service project ----
resource "google_compute_shared_vpc_host_project" "host" {
  project = var.host_project_id
}

resource "google_compute_shared_vpc_service_project" "service" {
  host_project    = google_compute_shared_vpc_host_project.host.project
  service_project = var.service_project_id
}

# ---- The Shared VPC network ----
resource "google_compute_network" "shared_vpc" {
  project                 = var.host_project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"

  depends_on = [google_compute_shared_vpc_host_project.host]
}

# ---- Two regular subnets, from slice(subnet_definitions, 0, 2) ----
# - secondary_ip_range blocks are created only when pods/services CIDRs are set
#   (the GKE node subnet has them; the other-region subnet does not).
# - log_config (VPC flow logs) is enabled per-subnet via the flow_logs flag.
resource "google_compute_subnetwork" "subnets" {
  for_each = local.subnets_by_name

  project       = var.host_project_id
  name          = each.value.name
  region        = each.value.region
  network       = google_compute_network.shared_vpc.id
  ip_cidr_range = each.value.primary_cidr

  # Private Google Access so private nodes can reach Google APIs without public IPs.
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = each.value.pods_cidr != null ? [each.value.pods_cidr] : []
    content {
      range_name    = var.pods_range_name
      ip_cidr_range = secondary_ip_range.value
    }
  }

  dynamic "secondary_ip_range" {
    for_each = each.value.services_cidr != null ? [each.value.services_cidr] : []
    content {
      range_name    = var.services_range_name
      ip_cidr_range = secondary_ip_range.value
    }
  }

  dynamic "log_config" {
    for_each = each.value.flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# ---- Proxy-only subnet for L7 internal load balancers / Gateway API ----
# Same region as the GKE node subnet. Flow logs are not applicable to
# REGIONAL_MANAGED_PROXY subnets.
resource "google_compute_subnetwork" "proxy_only" {
  project       = var.host_project_id
  name          = var.proxy_subnet_name
  region        = var.region
  network       = google_compute_network.shared_vpc.id
  ip_cidr_range = var.proxy_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

# ---- Cloud Router + NAT for outbound traffic from private nodes ----
# In the primary region (where the GKE private nodes run).
resource "google_compute_router" "router" {
  project = var.host_project_id
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.shared_vpc.id
}

resource "google_compute_router_nat" "nat" {
  project                            = var.host_project_id
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ---- Firewall: deny-all baseline + explicit allows ----
resource "google_compute_firewall" "deny_all_ingress" {
  project       = var.host_project_id
  name          = "${var.network_name}-deny-all-ingress"
  network       = google_compute_network.shared_vpc.name
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# Allow internal traffic within the VPC (nodes, pods, services, peer subnet).
resource "google_compute_firewall" "allow_internal" {
  project       = var.host_project_id
  name          = "${var.network_name}-allow-internal"
  network       = google_compute_network.shared_vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = local.internal_source_ranges

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}

# Allow the GKE control plane to reach kubelet/webhooks on the nodes.
resource "google_compute_firewall" "allow_master_to_nodes" {
  project       = var.host_project_id
  name          = "${var.network_name}-allow-master"
  network       = google_compute_network.shared_vpc.name
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [var.master_ipv4_cidr_block]

  allow {
    protocol = "tcp"
    ports    = ["443", "10250", "8443", "9443", "15017"]
  }
}

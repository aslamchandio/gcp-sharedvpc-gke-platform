###############################################################################
# dev/gke.auto.tfvars   (auto-loaded by Terraform)
# GKE module inputs: cluster, nodes, release, control-plane access.
###############################################################################

cluster_name    = "cluster" # suffix -> it-dev-standard
regional        = true      # REGIONAL: HA control plane across the region's zones
node_zone_count = 1         # nodes stay in 1 zone (raise to spread nodes for HA)

release_channel = "REGULAR"
# kubernetes_version = "1.30" # optional min_master_version floor; null = channel default

# ---- System node pool --------------------------------------------------------
node_machine_type = "e2-standard-2"
node_disk_size_gb = 50
node_disk_type    = "pd-balanced" # faster node boot than pd-standard
system_node_count = 1
# system_pool_single_zone defaults to false; dev is already single-zone (zonal).

# ---- Default Spot node pool (general/burst workloads; system pool stays on-demand)
default_pool_enabled      = false # removed: cluster runs on system pool + NAP only
default_pool_machine_type = "e2-standard-4"
default_pool_min_nodes    = 0 # scale to zero when idle
default_pool_max_nodes    = 3 # dev: smaller ceiling
default_pool_taint        = false

deletion_protection = false # dev clusters are disposable

# ---- Control-plane authorized networks (who can reach the IP endpoint) -------
master_authorized_networks = [
  {
    cidr_block   = "203.0.113.10/32" # replace with your admin/CI public IP
    display_name = "laptop"
  },
]

# ---- DNS-based control-plane endpoint (IAM-gated) ----------------------------
dns_endpoint_enabled                = true
dns_endpoint_allow_external_traffic = true # reachable from your laptop (IAM-gated)

###############################################################################
# prod/gke.auto.tfvars   (auto-loaded by Terraform)
# GKE module inputs: cluster, nodes, release, control-plane access.
###############################################################################

cluster_name    = "cluster" # suffix -> it-prod-standard
regional        = true      # 3-zone HA control plane
node_zone_count = 1

release_channel = "REGULAR"
# kubernetes_version = "1.30" # optional min_master_version floor; null = channel default

# ---- System node pool --------------------------------------------------------
node_machine_type       = "e2-standard-2" # 8GB: fits all system pods on one node
node_disk_size_gb       = 50
node_disk_type          = "pd-balanced"
system_node_count       = 1
system_pool_single_zone = true # one node, pinned to a single zone

# ---- Default Spot node pool (general/burst workloads; system pool stays on-demand)
default_pool_enabled      = false # removed: cluster runs on system pool + NAP only
default_pool_machine_type = "e2-standard-4"
default_pool_min_nodes    = 0 # scale to zero when idle
default_pool_max_nodes    = 6
default_pool_taint        = false # default landing zone for general pods

# Temporarily false to permit the rebuild; set back to true once healthy.
deletion_protection = false

# ---- Control-plane authorized networks (who can reach the API endpoint) ------
master_authorized_networks = [
  {
    cidr_block   = "203.0.113.10/32" # replace with your admin/CI public IP
    display_name = "my-ip"
  },
]

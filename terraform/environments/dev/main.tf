###############################################################################
# dev/main.tf
# Composition: wire the reusable modules for the dev environment.
#
# Ordering:
#   apis ──▶ network ─┐
#        └─▶ iam ─────┴──▶ gke
#
# gke uses module-level depends_on so the cluster build waits for ALL of the
# Shared VPC IAM bindings + Cloud NAT (not just the subnet/SA it references
# directly) — otherwise the first nodes can race ahead of egress/networkUser.
###############################################################################

module "apis" {
  source = "../../modules/apis"

  host_project_id    = var.host_project_id
  service_project_id = var.service_project_id
}

module "network" {
  source = "../../modules/network"

  host_project_id        = var.host_project_id
  service_project_id     = var.service_project_id
  region                 = var.region
  network_name           = local.network_name
  subnet_definitions     = local.prefixed_subnets
  proxy_subnet_name      = local.proxy_subnet_name
  proxy_subnet_cidr      = var.proxy_subnet_cidr
  master_ipv4_cidr_block = var.master_ipv4_cidr_block

  depends_on = [module.apis]
}

module "iam" {
  source = "../../modules/iam"

  host_project_id    = var.host_project_id
  service_project_id = var.service_project_id
  cluster_name       = local.gke_cluster_name
  gke_subnet_name    = module.network.gke_subnet_name
  gke_subnet_region  = module.network.gke_subnet_region

  depends_on = [module.apis]
}

module "gke" {
  source = "../../modules/gke"

  service_project_id = var.service_project_id
  region             = var.region
  cluster_name       = local.gke_cluster_name

  regional        = var.regional
  node_zone_count = var.node_zone_count

  network_id          = module.network.network_id
  subnet_id           = module.network.gke_subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  master_ipv4_cidr_block     = var.master_ipv4_cidr_block
  master_authorized_networks = var.master_authorized_networks

  dns_endpoint_enabled                = var.dns_endpoint_enabled
  dns_endpoint_allow_external_traffic = var.dns_endpoint_allow_external_traffic

  node_service_account_email = module.iam.node_service_account_email

  release_channel    = var.release_channel
  kubernetes_version = var.kubernetes_version
  node_machine_type  = var.node_machine_type
  node_disk_size_gb  = var.node_disk_size_gb
  node_disk_type     = var.node_disk_type
  system_node_count  = var.system_node_count

  system_pool_single_zone = var.system_pool_single_zone

  # Default Spot node pool (system pool stays on-demand).
  default_pool_enabled      = var.default_pool_enabled
  default_pool_machine_type = var.default_pool_machine_type
  default_pool_min_nodes    = var.default_pool_min_nodes
  default_pool_max_nodes    = var.default_pool_max_nodes
  default_pool_taint        = var.default_pool_taint

  deletion_protection = var.deletion_protection
  labels              = merge(var.labels, local.common_tags)

  depends_on = [module.iam, module.network]
}

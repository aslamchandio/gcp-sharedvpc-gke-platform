###############################################################################
# dev/locals.tf
# Per-environment naming + tagging convention so each env is distinguishable.
###############################################################################

locals {
  owners      = var.business_division # e.g. "it"
  environment = var.environment_name  # e.g. "dev"
  name        = "${var.business_division}-${var.environment_name}"

  common_tags = {
    owners      = local.owners
    environment = local.environment
  }

  # Cluster name = prefix + suffix.  e.g. it-dev-standard
  gke_cluster_name = "${local.name}-${var.cluster_name}"

  # ---- Every network resource carries the env prefix --------------------------
  # The network module derives router/NAT/firewall names from network_name, so
  # prefixing these three propagates the convention to all of them.
  network_name      = "${local.name}-vpc"   # it-dev-vpc (-> -router, -nat, -*-firewall)
  proxy_subnet_name = "${local.name}-proxy" # it-dev-proxy

  # Subnet names in tfvars are bare suffixes; prefix them here. e.g. it-dev-gke
  prefixed_subnets = [
    for s in var.subnet_definitions : merge(s, { name = "${local.name}-${s.name}" })
  ]
}

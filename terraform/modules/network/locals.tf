###############################################################################
# modules/network/locals.tf
# slice() usage for subnet selection + derived helpers.
###############################################################################

locals {
  # ---- slice(): create exactly the first two regular subnets.
  selected_subnets = slice(var.subnet_definitions, 0, 2)

  # Keyed map so for_each yields stable resource addresses (not list-index churn).
  subnets_by_name = { for s in local.selected_subnets : s.name => s }

  # First selected subnet hosts the GKE nodes (validated in variables.tf).
  gke_subnet = local.selected_subnets[0]

  # Internal-allow source ranges: every created subnet's primary range plus the
  # GKE Pod/Service ranges (compact() drops nulls from non-GKE subnets).
  internal_source_ranges = compact(concat(
    [for s in local.selected_subnets : s.primary_cidr],
    [local.gke_subnet.pods_cidr, local.gke_subnet.services_cidr],
  ))
}

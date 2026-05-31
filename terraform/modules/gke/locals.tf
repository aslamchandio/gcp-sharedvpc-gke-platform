###############################################################################
# modules/gke/locals.tf
# Zone discovery + zonal/regional location resolution.
###############################################################################

# Zones discovered dynamically (no hardcoded zone list).
data "google_compute_zones" "available" {
  project = var.service_project_id
  region  = var.region
  status  = "UP"
}

locals {
  # slice(): the first N available zones in the region.
  zones = slice(
    data.google_compute_zones.available.names,
    0,
    min(var.node_zone_count, length(data.google_compute_zones.available.names))
  )

  # Regional  -> location is the region, nodes spread across `zones`.
  # Zonal     -> location is a single zone, node_locations omitted (null).
  location       = var.regional ? var.region : local.zones[0]
  node_locations = var.regional ? local.zones : null
}

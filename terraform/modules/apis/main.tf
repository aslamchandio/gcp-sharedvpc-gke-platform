###############################################################################
# modules/apis/main.tf
# Enable required Google APIs per project (idempotent). disable_on_destroy =
# false so tearing down this stack never disables APIs other workloads may use.
###############################################################################

resource "google_project_service" "host" {
  for_each = toset(var.host_apis)

  project            = var.host_project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_project_service" "service" {
  for_each = toset(var.service_apis)

  project            = var.service_project_id
  service            = each.value
  disable_on_destroy = false
}

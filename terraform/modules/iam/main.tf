###############################################################################
# modules/iam/main.tf
# Shared VPC IAM wiring (least privilege) + dedicated GKE node service account.
###############################################################################

# Service-project number is needed to build the Google-managed Cloud Services
# identity that requires networkUser on the host's Shared VPC subnet.
data "google_project" "service" {
  project_id = var.service_project_id
}

locals {
  cloud_services_sa = "serviceAccount:${data.google_project.service.number}@cloudservices.gserviceaccount.com"
}

# ---- Force-create the GKE service agent (container-engine-robot) in the
# service project. GCP provisions this SA lazily, so we trigger it explicitly
# and reference its email below — otherwise the IAM bindings race ahead of the
# SA's existence ("service account ... does not exist").
resource "google_project_service_identity" "gke_robot" {
  provider = google-beta
  project  = var.service_project_id
  service  = "container.googleapis.com"
}

# ---- Service project's Google-managed SAs need networkUser on the GKE node
# subnet only (NOT the whole host project, not the unused peer subnet).
resource "google_compute_subnetwork_iam_member" "gke_robot_network_user" {
  project    = var.host_project_id
  region     = var.gke_subnet_region
  subnetwork = var.gke_subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_project_service_identity.gke_robot.email}"
}

resource "google_compute_subnetwork_iam_member" "cloud_services_network_user" {
  project    = var.host_project_id
  region     = var.gke_subnet_region
  subnetwork = var.gke_subnet_name
  role       = "roles/compute.networkUser"
  member     = local.cloud_services_sa
}

# ---- GKE robot SA needs hostServiceAgentUser to manage firewall rules on host.
resource "google_project_iam_member" "host_service_agent_user" {
  project = var.host_project_id
  role    = "roles/container.hostServiceAgentUser"
  member  = "serviceAccount:${google_project_service_identity.gke_robot.email}"
}

# ---- Dedicated, least-privilege node service account (no default Compute SA). --
resource "google_service_account" "gke_nodes" {
  project      = var.service_project_id
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE node service account for ${var.cluster_name}"
}

# Minimal roles needed for logging, monitoring, metadata, and image pulls.
resource "google_project_iam_member" "gke_nodes_roles" {
  for_each = toset(var.node_iam_roles)

  project = var.service_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

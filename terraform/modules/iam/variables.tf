###############################################################################
# modules/iam/variables.tf
###############################################################################

variable "host_project_id" {
  description = "GCP project that hosts the Shared VPC (project-a)."
  type        = string
}

variable "service_project_id" {
  description = "GCP service project where the GKE cluster lives (project-b)."
  type        = string
}

variable "cluster_name" {
  description = "Cluster name — used to name the dedicated node service account."
  type        = string
}

variable "gke_subnet_name" {
  description = "Name of the GKE node subnet (networkUser is scoped to this subnet only)."
  type        = string
}

variable "gke_subnet_region" {
  description = "Region of the GKE node subnet."
  type        = string
}

variable "node_iam_roles" {
  description = "Minimal project roles granted to the node service account."
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ]
}

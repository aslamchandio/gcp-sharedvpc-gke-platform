###############################################################################
# modules/apis/variables.tf
###############################################################################

variable "host_project_id" {
  description = "GCP project that hosts the Shared VPC (project-a)."
  type        = string
}

variable "service_project_id" {
  description = "GCP service project where the GKE cluster lives (project-b)."
  type        = string
}

variable "host_apis" {
  description = "APIs to enable on the host project. container.googleapis.com is required on the HOST for Shared-VPC GKE (host service agent / firewall management)."
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "container.googleapis.com",
  ]
}

variable "service_apis" {
  description = "APIs to enable on the service project."
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "container.googleapis.com",
  ]
}

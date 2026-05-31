###############################################################################
# modules/gke/outputs.tf
###############################################################################

output "cluster_name" {
  description = "Name of the GKE cluster."
  value       = google_container_cluster.primary.name
}

output "location" {
  description = "Cluster location (region if regional, single zone if zonal)."
  value       = local.location
}

output "node_zones" {
  description = "Zones the cluster spreads nodes across."
  value       = local.zones
}

output "cluster_endpoint" {
  description = "GKE control plane endpoint."
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 cluster CA certificate."
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Workload Identity pool for binding KSAs to GSAs."
  value       = google_container_cluster.primary.workload_identity_config[0].workload_pool
}

output "dns_endpoint" {
  description = "DNS-based control-plane endpoint (null if not enabled)."
  value       = try(google_container_cluster.primary.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint, null)
}

output "get_credentials_command" {
  description = "Command to fetch kubeconfig for the private cluster."
  value = format(
    "gcloud container clusters get-credentials %s --%s %s --project %s",
    google_container_cluster.primary.name,
    var.regional ? "region" : "zone",
    local.location,
    var.service_project_id,
  )
}

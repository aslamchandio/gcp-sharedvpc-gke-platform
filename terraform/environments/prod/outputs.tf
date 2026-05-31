###############################################################################
# prod/outputs.tf
###############################################################################

output "network_self_link" {
  description = "Self link of the Shared VPC network."
  value       = module.network.network_self_link
}

output "subnet_ids" {
  description = "Map of created subnet name => subnet id."
  value       = module.network.subnet_ids
}

output "subnet_self_links" {
  description = "Map of created subnet name => self link."
  value       = module.network.subnet_self_links
}

output "cluster_name" {
  description = "Name of the GKE cluster."
  value       = module.gke.cluster_name
}

output "cluster_location" {
  description = "Cluster location (region in prod)."
  value       = module.gke.location
}

output "node_zones" {
  description = "Zones the cluster spreads nodes across."
  value       = module.gke.node_zones
}

output "cluster_endpoint" {
  description = "GKE control plane endpoint."
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Workload Identity pool for binding KSAs to GSAs."
  value       = module.gke.workload_identity_pool
}

output "get_credentials_command" {
  description = "Command to fetch kubeconfig for the private cluster."
  value       = module.gke.get_credentials_command
}

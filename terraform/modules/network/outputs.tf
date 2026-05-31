###############################################################################
# modules/network/outputs.tf
###############################################################################

output "network_id" {
  description = "Full resource id of the Shared VPC network."
  value       = google_compute_network.shared_vpc.id
}

output "network_self_link" {
  description = "Self link of the Shared VPC network."
  value       = google_compute_network.shared_vpc.self_link
}

output "network_name" {
  description = "Name of the Shared VPC network."
  value       = google_compute_network.shared_vpc.name
}

output "subnet_ids" {
  description = "Map of created subnet name => subnet id (the two slice()-selected subnets)."
  value       = { for name, s in google_compute_subnetwork.subnets : name => s.id }
}

output "subnet_self_links" {
  description = "Map of created subnet name => self link."
  value       = { for name, s in google_compute_subnetwork.subnets : name => s.self_link }
}

output "gke_subnet_id" {
  description = "Id of the subnet that hosts the GKE nodes."
  value       = google_compute_subnetwork.subnets[local.gke_subnet.name].id
}

output "gke_subnet_name" {
  description = "Name of the subnet that hosts the GKE nodes."
  value       = google_compute_subnetwork.subnets[local.gke_subnet.name].name
}

output "gke_subnet_region" {
  description = "Region of the subnet that hosts the GKE nodes."
  value       = google_compute_subnetwork.subnets[local.gke_subnet.name].region
}

output "pods_range_name" {
  description = "Secondary-range name for Pod IPs."
  value       = var.pods_range_name
}

output "services_range_name" {
  description = "Secondary-range name for Service IPs."
  value       = var.services_range_name
}

output "nat_id" {
  description = "Cloud NAT id (lets downstream wire ordering on egress readiness)."
  value       = google_compute_router_nat.nat.id
}

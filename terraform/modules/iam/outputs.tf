###############################################################################
# modules/iam/outputs.tf
###############################################################################

output "node_service_account_email" {
  description = "Email of the dedicated GKE node service account."
  value       = google_service_account.gke_nodes.email
}

output "gke_robot_email" {
  description = "Email of the GKE service agent (container-engine-robot)."
  value       = google_project_service_identity.gke_robot.email
}

# Exported so the GKE module can depend on the Shared VPC bindings being in
# place (referencing these ids creates the implicit ordering edge).
output "shared_vpc_binding_ids" {
  description = "IAM binding ids that must exist before the cluster uses the subnet."
  value = [
    google_compute_subnetwork_iam_member.gke_robot_network_user.id,
    google_compute_subnetwork_iam_member.cloud_services_network_user.id,
    google_project_iam_member.host_service_agent_user.id,
  ]
}

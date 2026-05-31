###############################################################################
# modules/apis/outputs.tf
# Exported so downstream modules can wire `depends_on = [module.apis]` and be
# certain the APIs are enabled before they create resources.
###############################################################################

output "host_service_ids" {
  description = "Enabled host-project API resource ids."
  value       = { for k, s in google_project_service.host : k => s.id }
}

output "service_service_ids" {
  description = "Enabled service-project API resource ids."
  value       = { for k, s in google_project_service.service : k => s.id }
}

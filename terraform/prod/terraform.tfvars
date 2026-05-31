###############################################################################
# prod/network.auto.tfvars   (auto-loaded by Terraform)
# Foundation (projects/region/naming/labels) + network module inputs.
###############################################################################

host_project_id    = "my-host-project-prod"    # Shared VPC host (project-a)
service_project_id = "my-service-project-prod" # GKE service project (project-b)

region = "us-central1"

# ---- Naming / tagging (shared by network + gke; drives it-prod-* names) ------
business_division = "it"
environment_name  = "prod"

labels = {
  managed-by = "terraform"
  platform   = "ai-product-catalog"
  env        = "prod"
}

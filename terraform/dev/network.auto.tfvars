###############################################################################
# dev/network.auto.tfvars   (auto-loaded by Terraform)
# Foundation (projects/region/naming/labels) + network module inputs.
#
# NOTE: the project IDs below are PLACEHOLDERS. Dev needs its OWN host/service
# projects (distinct from prod), or it collides with prod on the Shared-VPC host
# + service attachment. Set real values before apply.
###############################################################################

host_project_id    = "my-host-project-dev"    # replace with your Shared-VPC host project ID
service_project_id = "my-service-project-dev" # replace with your GKE service project ID

# region must match the first (GKE) subnet's region below.
region = "us-west1"

# ---- Naming / tagging (shared by network + gke; drives it-dev-* names) -------
business_division = "it"
environment_name  = "dev"

labels = {
  environment = "dev"
  team        = "platform"
  managed-by  = "terraform"
}

# ---- VPC subnets -------------------------------------------------------------
# Subnet names are bare suffixes -> prefixed to it-dev-<name> in locals.tf.
# network/proxy names are derived (it-dev-vpc / it-dev-proxy).
subnet_definitions = [
  {
    name          = "gke-us-west1" # -> it-dev-gke
    region        = "us-west1"
    primary_cidr  = "192.168.32.0/20" # fixed (was 192.168.032.0/20 - invalid octet)
    pods_cidr     = "10.245.0.0/16"
    services_cidr = "10.33.0.0/20"
    flow_logs     = true

  },
  {
    # DR-region placeholder subnet (no GKE secondary ranges in dev).
    name         = "me-central1" # -> it-dev-eu
    region       = "me-central1"
    primary_cidr = "172.25.2.0/24"
    flow_logs    = true
  },
]

proxy_subnet_cidr = "192.168.2.0/24"

# Control-plane /28 (used by the master->nodes firewall + the cluster).
master_ipv4_cidr_block = "172.16.2.0/28"

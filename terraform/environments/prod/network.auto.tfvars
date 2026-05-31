###############################################################################
# prod/network.auto.tfvars   (auto-loaded by Terraform)
# Network module inputs. Project IDs live in prod/terraform.tfvars.
###############################################################################

# ---- VPC subnets -------------------------------------------------------------
# Subnet names are bare suffixes -> prefixed to it-prod-<name> in locals.tf.
# network/proxy names are derived (it-prod-vpc / it-prod-proxy).

# region must match the first (GKE) subnet's region below.
region = "us-central1"

# ---- Naming / tagging (shared by network + gke; drives it-dev-* names) -------
business_division = "it"
environment_name  = "prod"

labels = {
  environment = "prod"
  team        = "platform"
  managed-by  = "terraform"
}

subnet_definitions = [
  {
    name          = "gke-us-central1" # -> it-prod-gke
    region        = "us-central1"     # GKE node region (must equal var.region)
    primary_cidr  = "192.168.16.0/20"
    flow_logs     = true
    pods_cidr     = "10.244.0.0/16"
    services_cidr = "10.32.0.0/20"
  },
  {
    name         = "eu-west2"     # -> it-prod-eu
    region       = "europe-west2" # DR region (no GKE secondary ranges)
    primary_cidr = "172.25.1.0/24"
    flow_logs    = true
  },
]

proxy_subnet_cidr = "192.168.1.0/24"

# Control-plane /28 (used by the master->nodes firewall + the cluster).
master_ipv4_cidr_block = "172.16.1.0/28"

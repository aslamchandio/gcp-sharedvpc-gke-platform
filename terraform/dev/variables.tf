###############################################################################
# dev/variables.tf
# Root inputs for the dev environment (driven by terraform.tfvars).
###############################################################################

variable "host_project_id" {
  description = "GCP project that hosts the Shared VPC (project-a)."
  type        = string
}

variable "service_project_id" {
  description = "GCP service project where the GKE cluster lives (project-b)."
  type        = string
}

variable "region" {
  description = "Primary region for nodes, proxy subnet, router/NAT, and (if regional) the control plane."
  type        = string
}

# ---- Naming / tagging convention -------------------------------------------
variable "business_division" {
  description = "Owning business division, used as the name prefix (e.g. \"it\")."
  type        = string
}

variable "environment_name" {
  description = "Environment short name, used in the name + common_tags (e.g. \"dev\")."
  type        = string
}

# ---- Networking -------------------------------------------------------------
# NOTE: network_name and proxy_subnet_name are derived from the naming
# convention in locals.tf (it-<env>-vpc / it-<env>-proxy). Subnet `name`s here
# are bare suffixes (e.g. "gke") and get the env prefix applied in locals.tf.
variable "subnet_definitions" {
  description = "Ordered candidate subnets (first two created via slice); names are bare suffixes, prefixed in locals."
  type = list(object({
    name          = string
    region        = string
    primary_cidr  = string
    flow_logs     = bool
    pods_cidr     = optional(string)
    services_cidr = optional(string)
  }))
}

variable "proxy_subnet_cidr" {
  description = "CIDR for the REGIONAL_MANAGED_PROXY subnet."
  type        = string
}

# ---- Cluster ----------------------------------------------------------------
variable "cluster_name" {
  description = "Cluster name SUFFIX; combined with business_division + environment_name into gke_cluster_name (e.g. \"standard\" -> \"it-dev-standard\")."
  type        = string
}

variable "regional" {
  description = "Regional (3-zone HA) vs zonal control plane. Zonal is faster to provision (dev default)."
  type        = bool
}

variable "node_zone_count" {
  description = "How many zones to spread nodes across."
  type        = number
}

variable "master_ipv4_cidr_block" {
  description = "RFC1918 /28 for the GKE control plane."
  type        = string
}

variable "master_authorized_networks" {
  description = "CIDRs allowed to reach the IP-based control-plane endpoint."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
}

variable "dns_endpoint_enabled" {
  description = "Enable the DNS-based control-plane endpoint (IAM-gated)."
  type        = bool
  default     = false
}

variable "dns_endpoint_allow_external_traffic" {
  description = "Allow the DNS endpoint from outside Google Cloud (still IAM-gated)."
  type        = bool
  default     = false
}

variable "release_channel" {
  description = "GKE release channel."
  type        = string
}

variable "kubernetes_version" {
  description = "Control-plane version floor (min_master_version). null = channel default."
  type        = string
  default     = null
}

variable "node_machine_type" {
  description = "Machine type for the system node pool."
  type        = string
}

variable "node_disk_size_gb" {
  description = "Boot disk size (GB) for system nodes."
  type        = number
}

variable "node_disk_type" {
  description = "Boot disk type (pd-balanced recommended for faster boot)."
  type        = string
}

variable "system_node_count" {
  description = "Total nodes in the system node pool."
  type        = number
}

variable "system_pool_single_zone" {
  description = "Pin the system node pool to one zone (use with system_node_count = 1)."
  type        = bool
  default     = false
}

# ---- Default Spot node pool -------------------------------------------------
variable "default_pool_enabled" {
  description = "Create the default Spot node pool alongside the on-demand system pool."
  type        = bool
  default     = true
}

variable "default_pool_machine_type" {
  description = "Machine type for the default Spot node pool."
  type        = string
  default     = "e2-standard-4"
}

variable "default_pool_min_nodes" {
  description = "Total minimum nodes in the default Spot pool (0 = scale to zero)."
  type        = number
  default     = 0
}

variable "default_pool_max_nodes" {
  description = "Total maximum nodes in the default Spot pool."
  type        = number
  default     = 6
}

variable "default_pool_taint" {
  description = "Taint the default Spot pool so only Spot-tolerant workloads schedule there."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Block `terraform destroy` of the cluster."
  type        = bool
}

variable "labels" {
  description = "Common resource labels."
  type        = map(string)
}

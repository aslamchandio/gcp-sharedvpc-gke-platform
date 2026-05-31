###############################################################################
# modules/gke/variables.tf
###############################################################################

variable "service_project_id" {
  description = "GCP service project where the GKE cluster lives (project-b)."
  type        = string
}

variable "region" {
  description = "Region the cluster/nodes live in. Used as control-plane location when regional = true."
  type        = string
}

variable "cluster_name" {
  description = "Name of the private GKE cluster."
  type        = string
}

# ---- Provisioning-speed lever ----------------------------------------------
# regional = true  -> 3-zone HA control plane (prod). Slower to create.
# regional = false -> single-zone (zonal) control plane (dev). Much faster.
variable "regional" {
  description = "If true, create a regional (multi-zone) control plane; if false, a zonal cluster."
  type        = bool
  default     = true
}

variable "node_zone_count" {
  description = "How many zones from the region to spread nodes across (slice of available zones)."
  type        = number
  default     = 3

  validation {
    condition     = var.node_zone_count >= 1 && var.node_zone_count <= 4
    error_message = "node_zone_count must be between 1 and 4."
  }
}

# ---- Networking (from the network module) ----------------------------------
variable "network_id" {
  description = "Full id of the Shared VPC network."
  type        = string
}

variable "subnet_id" {
  description = "Full id of the GKE node subnet."
  type        = string
}

variable "pods_range_name" {
  description = "Secondary-range name for Pod IPs."
  type        = string
}

variable "services_range_name" {
  description = "Secondary-range name for Service IPs."
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "RFC1918 /28 for the GKE control plane (peered Google-managed VPC)."
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
  description = "Enable the DNS-based control-plane endpoint (access via a DNS name, gated by IAM `container.clusters.connect` instead of IP allowlists)."
  type        = bool
  default     = false
}

variable "dns_endpoint_allow_external_traffic" {
  description = "Allow the DNS endpoint to be reached from OUTSIDE Google Cloud (still IAM-gated). false = reachable only from within Google's network / the VPC."
  type        = bool
  default     = false
}

# ---- Identity ---------------------------------------------------------------
variable "node_service_account_email" {
  description = "Dedicated node service account (from the iam module)."
  type        = string
}

# ---- Release / nodes --------------------------------------------------------
variable "release_channel" {
  description = "GKE release channel."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be one of RAPID, REGULAR, STABLE."
  }
}

variable "kubernetes_version" {
  description = "Control-plane version (min_master_version). null = use the release channel's default. Accepts a prefix like \"1.30\" or a full version; must exist in the chosen channel."
  type        = string
  default     = null
}

variable "node_machine_type" {
  description = "Machine type for the system node pool."
  type        = string
}

variable "node_disk_size_gb" {
  description = "Boot disk size (GB) for system node pool nodes."
  type        = number

  validation {
    condition     = var.node_disk_size_gb >= 30
    error_message = "node_disk_size_gb must be at least 30 GB."
  }
}

variable "node_disk_type" {
  description = "Boot disk type (pd-balanced recommended for faster boot)."
  type        = string
  default     = "pd-balanced"

  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd"], var.node_disk_type)
    error_message = "node_disk_type must be one of pd-standard, pd-balanced, pd-ssd."
  }
}

variable "system_node_count" {
  description = "Total nodes in the system node pool (across its node_locations)."
  type        = number

  validation {
    condition     = var.system_node_count >= 1
    error_message = "system_node_count must be at least 1."
  }
}

variable "system_pool_single_zone" {
  description = "Pin the system node pool to ONE zone (node_locations = first discovered zone), even on a regional cluster. Use with system_node_count = 1 for a single-node, single-zone pool. null/false => pool spans the cluster's zones."
  type        = bool
  default     = false
}

# ---- Default Spot node pool (general/burst workloads) -----------------------
# Created WITH the cluster. Carries general workloads on Spot VMs for cost. The
# `system` pool above stays on-demand for system-critical components. Spot nodes
# get GKE's built-in label cloud.google.com/gke-spot=true and can be reclaimed
# with ~15s notice, so keep nothing stateful here.
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
  description = "Total minimum nodes in the default Spot pool (cluster-wide). 0 = scale to zero when idle."
  type        = number
  default     = 0

  validation {
    condition     = var.default_pool_min_nodes >= 0
    error_message = "default_pool_min_nodes must be >= 0."
  }
}

variable "default_pool_max_nodes" {
  description = "Total maximum nodes in the default Spot pool (cluster-wide)."
  type        = number
  default     = 6

  validation {
    condition     = var.default_pool_max_nodes >= 1
    error_message = "default_pool_max_nodes must be >= 1."
  }
}

variable "default_pool_taint" {
  description = "Add a NoSchedule taint (cloud.google.com/gke-spot=true) so ONLY Spot-tolerant workloads land on the default pool. false => pool is the default landing zone for any pod."
  type        = bool
  default     = false
}

# ---- Node auto-provisioning (NAP) limits, backs Custom Compute Classes ------
variable "nap_cpu_min" {
  description = "Cluster-wide NAP minimum vCPUs. Keep 0 so NAP does not force a capacity floor (it only bursts for unschedulable pods)."
  type        = number
  default     = 0
}

variable "nap_cpu_max" {
  description = "Cluster-wide NAP maximum vCPUs."
  type        = number
  default     = 100
}

variable "nap_memory_min" {
  description = "Cluster-wide NAP minimum memory (GB). Keep 0 so NAP does not force a capacity floor."
  type        = number
  default     = 0
}

variable "nap_memory_max" {
  description = "Cluster-wide NAP maximum memory (GB)."
  type        = number
  default     = 400
}

# ---- Safety -----------------------------------------------------------------
variable "deletion_protection" {
  description = "Block `terraform destroy` of the cluster. Keep true in prod."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Common resource labels."
  type        = map(string)
  default     = {}
}

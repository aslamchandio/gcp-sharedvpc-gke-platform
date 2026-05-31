###############################################################################
# modules/network/variables.tf
# snake_case names, explicit types, descriptions, and validation per standards.
###############################################################################

variable "host_project_id" {
  description = "GCP project that hosts the Shared VPC (project-a)."
  type        = string
}

variable "service_project_id" {
  description = "GCP service project attached to the Shared VPC (project-b)."
  type        = string
}

variable "region" {
  description = "Primary region — GKE node subnet, proxy subnet, router/NAT."
  type        = string
}

variable "network_name" {
  description = "Name of the Shared VPC network created in the host project."
  type        = string
}

# Regular (non-proxy) subnets. slice() selects the first two, demonstrating the
# requested use of slice() when creating the VPC subnets. Only the GKE node
# subnet (first entry) needs pods_cidr/services_cidr.
variable "subnet_definitions" {
  description = "Ordered list of candidate regular subnets; the first two are created."
  type = list(object({
    name          = string
    region        = string
    primary_cidr  = string
    flow_logs     = bool
    pods_cidr     = optional(string)
    services_cidr = optional(string)
  }))

  validation {
    condition     = length(var.subnet_definitions) >= 2
    error_message = "At least two subnet definitions are required (slice takes the first two)."
  }

  validation {
    # The first subnet is the GKE node subnet; it must carry secondary ranges
    # and live in the primary region.
    condition = (
      var.subnet_definitions[0].pods_cidr != null &&
      var.subnet_definitions[0].services_cidr != null &&
      var.subnet_definitions[0].region == var.region
    )
    error_message = "First subnet (GKE nodes) must define pods_cidr + services_cidr and use var.region."
  }
}

variable "proxy_subnet_name" {
  description = "Name of the proxy-only subnet (L7 ILB / Gateway API)."
  type        = string
}

variable "proxy_subnet_cidr" {
  description = "CIDR for the REGIONAL_MANAGED_PROXY subnet (same region as GKE nodes)."
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "GKE control-plane /28; allowed to reach kubelet/webhooks via firewall."
  type        = string
}

variable "pods_range_name" {
  description = "Secondary-range name used by GKE for Pod IPs."
  type        = string
  default     = "pods"
}

variable "services_range_name" {
  description = "Secondary-range name used by GKE for Service IPs."
  type        = string
  default     = "services"
}

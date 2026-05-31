###############################################################################
# dev/versions.tf
# Runtime + provider pinning and provider config for the dev root module.
# Default provider uses the host project; cross-project resources set `project`
# explicitly, so a single provider config (per provider) is sufficient.
###############################################################################

terraform {
  required_version = "~> 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.host_project_id
  region  = var.region
}

provider "google-beta" {
  project = var.host_project_id
  region  = var.region
}

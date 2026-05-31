###############################################################################
# modules/apis/versions.tf
# Modules declare provider requirements only — never provider config blocks.
###############################################################################

terraform {
  required_version = "~> 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

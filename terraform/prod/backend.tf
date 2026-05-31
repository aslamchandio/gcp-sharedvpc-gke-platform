###############################################################################
# prod/backend.tf
# Remote Terraform state — GCS backend (native locking + object versioning).
# Separate state per environment (prefix), per Terraform Standards.
###############################################################################

terraform {
  backend "gcs" {
    bucket = "aslam-terraform-bucket"
    prefix = "prod/shared-vpc-gke"
  }
}

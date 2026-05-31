###############################################################################
# dev/backend.tf
# Remote Terraform state — GCS backend (native locking + object versioning).
# Separate state per environment (prefix), per Terraform Standards.
#
# Bucket must exist with versioning enabled before `terraform init`:
#
#   gcloud storage buckets create gs://aslam-terraform-bucket \
#     --project <host-project> --location us-central1 --uniform-bucket-level-access
#   gcloud storage buckets update gs://aslam-terraform-bucket --versioning
###############################################################################

terraform {
  backend "gcs" {
    bucket = "aslam-terraform-bucket"
    prefix = "dev/shared-vpc-gke"
  }
}

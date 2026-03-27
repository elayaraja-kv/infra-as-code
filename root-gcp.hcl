# Root Terragrunt configuration - common settings for all environments
# Edit the `bucket` value below to the GCS bucket you will use for Terraform state.
# Set the environment variable GOOGLE_APPLICATION_CREDENTIALS with your service account JSON.


locals {
  project_id = get_env("GCP_PROJECT", "default-project")
  gcp_region = get_env("GCP_REGION", "australia-southeast2")

  # Parse path: {org}/{provider}/{env}/{plane}/{project}/{region}/{component}
  _path_components = split("/", path_relative_to_include())
  org              = local._path_components[0]
  provider         = local._path_components[1]
  environment      = local._path_components[2]
  plane            = local._path_components[3]
  project          = local._path_components[4]
  region           = local._path_components[5]
  component        = local._path_components[6]

  # Region short-name mapping (centralized)
  region_short_names = {
    "australia-southeast1" = "ause1"
    "australia-southeast2" = "ause2"
    "us-central1"          = "usc1"
    "us-east1"             = "use1"
    "us-west1"             = "usw1"
    "europe-west1"         = "euw1"
    "asia-southeast1"      = "asse1"
    "global"               = "gbl"
  }
  region_short = lookup(local.region_short_names, local.region, local.region)

  # Region subnets mapping (multiple subnets per region)
  region_subnets = {
    "australia-southeast1" = ["ause1"]
    "australia-southeast2" = ["ause2"]
    "us-central1"          = ["usc1"]
    "us-east1"             = ["use1"]
    "us-west1"             = ["usw1"]
    "europe-west1"         = ["euw1"]
    "asia-southeast1"      = ["asse1"]
    "global"               = []
  }
  subnets = lookup(local.region_subnets, local.region, [])

  # All labels (merged)
  labels = {
    # managed_by  = "atlantis"
    org         = "nz3es"
    environment = local.environment
    plane       = local.plane
    project     = local.project
    region      = local.region
    component   = local.component
  }
}
# Remote state configuration (GCS backend for remote state)
remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite" # or "skip", "error"
  }
  config = {
    bucket = "nz3es-tf-state-iac"
    prefix = "infra-as-code/${path_relative_to_include()}"
  }
}

# # Generate a small Terraform validation file in each working dir. This writes
# # a boolean variable whose default is the evaluated folder_layout_valid value.
# # Terraform's variable validation will fail during `plan`/`validate` if the
# # folder layout is invalid.

# generate "folder_validation" {
#   path      = "terragrunt_folder_validation.tf"
#   if_exists = "overwrite"
#   contents  = <<EOF
# variable "terragrunt_folder_validation_dummy" {
#   type    = bool
#   default = ${local.folder_layout_valid}

#   validation {
#     condition     = var.terragrunt_folder_validation_dummy == true
#     error_message = "Invalid folder layout: inferred environment='${local.inferred_environment}', inferred region='${local.inferred_region}'. Allowed environments: ${join(", ", local.allowed_environments)}. Allowed regions: ${join(", ", local.allowed_regions)}"
#   }
# }
# EOF
# }

# Provider config generation (commented out — upstream modules via tfr://
# have their own versions.tf. Provider project/region set via env vars:
# GOOGLE_PROJECT, GOOGLE_REGION, or gcloud application-default credentials).
# generate "provider" {
#   path      = "provider.tf"
#   if_exists = "skip"
#   contents  = <<EOF
# provider "google" {
#   project = "${local.project_id}"
#   region  = "${local.region}"
# }
#
# EOF
# }

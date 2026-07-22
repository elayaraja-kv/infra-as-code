# Root Terragrunt configuration - common settings for all environments
# Edit the `bucket` value below to the GCS bucket you will use for Terraform state.
# Set the environment variable GOOGLE_APPLICATION_CREDENTIALS with your service account JSON.


locals {
  # State bucket project (nz3es-infra-mgmt) — set via GCP_PROJECT env var
  state_project_id = get_env("GCP_PROJECT", "nz3es-infra-mgmt")
  gcp_region       = get_env("GCP_REGION", "australia-southeast2")

  # Parse path: {org}/{provider}/{env}/{plane}/{project}/{region}/{component}
  _path_components = split("/", path_relative_to_include())
  org              = local._path_components[0]
  provider         = local._path_components[1]
  environment      = local._path_components[2]
  plane            = local._path_components[3]
  project          = local._path_components[4]
  region           = local._path_components[5]
  component        = local._path_components[6]

  # Resource project — always derived from path (iac-01, iac-02, etc.)
  project_id = local.project

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
    bucket  = "nz3es-state"
    prefix  = "infra-as-code/${path_relative_to_include()}"
    project = local.state_project_id # nz3es-infra-mgmt — project hosting the state bucket
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

# Provider config generation. Sets user_project_override + billing_project so
# API-enablement/quota checks bill against the target project (local.project_id)
# instead of falling back to the credentials' own home project (e.g. the
# automation SA lives in nz3es-infra-mgmt, which caused 403 SERVICE_DISABLED
# errors against the wrong project number when this was left to provider
# defaults). google-beta is configured identically since several upstream
# modules (e.g. sql-db/postgresql) pin specific resources to it via
# `provider = google-beta`.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "google" {
  project               = "${local.project_id}"
  region                = "${local.gcp_region}"
  user_project_override = true
  billing_project       = "${local.project_id}"
}

provider "google-beta" {
  project               = "${local.project_id}"
  region                = "${local.gcp_region}"
  user_project_override = true
  billing_project       = "${local.project_id}"
}
EOF
}

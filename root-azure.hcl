# Root Terragrunt configuration for Azure deployments
# Set ARM_SUBSCRIPTION_ID, ARM_TENANT_ID env vars for auth.
# Use `az login` or service principal credentials via ARM_CLIENT_ID / ARM_CLIENT_SECRET.
#
# State backend requires a pre-existing Azure Storage Account:
#   TF_STATE_RESOURCE_GROUP   (default: nz3es-tf-state-rg)
#   TF_STATE_STORAGE_ACCOUNT  (default: nz3estfstate)

locals {
  # Parse path: {org}/{provider}/{env}/{plane}/{project}/{region}/{component}
  _path_components = split("/", path_relative_to_include())
  org         = local._path_components[0]
  provider    = local._path_components[1]
  environment = local._path_components[2]
  plane       = local._path_components[3]
  project     = local._path_components[4]
  region      = local._path_components[5]
  component   = local._path_components[6]

  # Azure region short-name mapping
  region_short_names = {
    "australiaeast"      = "ause"
    "australiasoutheast" = "ause2"
    "australiacentral"   = "ausc"
    "eastus"             = "use"
    "eastus2"            = "use2"
    "westus"             = "usw"
    "westus2"            = "usw2"
    "westeurope"         = "euw"
    "northeurope"        = "eun"
    "southeastasia"      = "asse"
    "eastasia"           = "ase"
    "global"             = "gbl"
  }
  region_short = lookup(local.region_short_names, local.region, local.region)

  # Azure tags (equivalent to GCP labels applied to all resources)
  tags = {
    org         = local.org
    environment = local.environment
    plane       = local.plane
    project     = local.project
    region      = local.region
    component   = local.component
    managed_by  = "terragrunt"
  }
}

# Remote state — Azure Storage Account backend
# Bootstrap: create the storage account manually or via a one-off script before first apply.
remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    resource_group_name  = get_env("TF_STATE_RESOURCE_GROUP", "nz3es-tf-state-rg")
    storage_account_name = get_env("TF_STATE_STORAGE_ACCOUNT", "nz3estfstate")
    container_name       = "tfstate"
    key                  = "infra-as-code/${path_relative_to_include()}/terraform.tfstate"
  }
}

# Generate azurerm provider — required for all Azure modules.
# Unlike GCP (where GOOGLE_PROJECT/GOOGLE_REGION configure everything via env vars),
# the azurerm provider mandates a `features {}` block in HCL — it cannot be satisfied
# by ARM_* env vars alone. ARM_SUBSCRIPTION_ID / ARM_TENANT_ID / ARM_CLIENT_ID /
# ARM_CLIENT_SECRET are still read automatically from the environment.
generate "provider" {
  path      = "provider.tf"
  if_exists = "skip"
  contents  = <<-EOF
    provider "azurerm" {
      features {}
    }
  EOF
}

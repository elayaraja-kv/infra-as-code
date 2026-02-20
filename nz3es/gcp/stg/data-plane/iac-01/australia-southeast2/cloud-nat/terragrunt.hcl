include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "cloud_nat" {
  path = "${get_repo_root()}/modules/gcp/cloud-nat/terragrunt.hcl"
}

locals {
  base_path = "${get_repo_root()}/${include.root.locals.org}/${include.root.locals.provider}/${include.root.locals.environment}/${include.root.locals.plane}/${include.root.locals.project}"
}

dependency "network" {
  config_path = "${local.base_path}/global/network"

  mock_outputs = {
    network_name = "mock-network"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  project_id  = include.root.locals.project_id
  region      = include.root.locals.region
  network     = dependency.network.outputs.network_name
  router      = "nat-router-${include.root.locals.region_short}"
  name        = "cloud-nat-${include.root.locals.region_short}"
}

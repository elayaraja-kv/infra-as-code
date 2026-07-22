include "root" {
  path   = find_in_parent_folders("root-gcp.hcl")
  expose = true
}

include "psc_endpoint" {
  path = "${get_repo_root()}/modules/gcp/psc-endpoint/terragrunt.hcl"
}

locals {
  # Reconstructs the sibling Cloud SQL instance's name (postgres-stg-01-ause2)
  instance_name = "${basename(dirname(dirname(get_terragrunt_dir())))}-${basename(dirname(get_terragrunt_dir()))}-${include.root.locals.region_short}"
}

dependency "network" {
  config_path = "${get_repo_root()}/${include.root.locals.org}/${include.root.locals.provider}/${include.root.locals.environment}/${include.root.locals.plane}/${include.root.locals.project}/global/network"

  mock_outputs = {
    network_self_link = "mock-network-self-link"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "postgres" {
  config_path = "../"

  mock_outputs = {
    instance_psc_attachment = "projects/mock/regions/mock/serviceAttachments/mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  project_id                = include.root.locals.project_id
  name                      = "${local.instance_name}-psc"
  region                    = include.root.locals.region
  network                   = dependency.network.outputs.network_self_link
  subnetwork                = include.root.locals.region_short
  target_service_attachment = dependency.postgres.outputs.instance_psc_attachment
  ip_address                = "10.1.0.20" # matches the pre-existing "db" placeholder in global/dns-zone/iac-internal
}

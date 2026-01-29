include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "valkey" {
  config_path = "../../memorystore/volatile-lru"

  mock_outputs = {
    ca_cert = "mock-ca-cert"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../../../../../../modules/secret-manager"
}

locals {
  _path_components = split("/", path_relative_to_include())
  secret_name      = local._path_components[length(local._path_components) - 1]
}

inputs = {
  project_id  = include.root.locals.project_id
  secret_id   = local.secret_name
  secret_data = dependency.valkey.outputs.ca_cert
  labels      = include.root.locals.labels
}

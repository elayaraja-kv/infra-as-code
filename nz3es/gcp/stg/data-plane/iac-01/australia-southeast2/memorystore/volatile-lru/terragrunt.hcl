include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "scp" {
  config_path = "../../service-connection-policy/valkey-psc"

  mock_outputs = {
    policy_ids = { "valkey-psc" = "mock-policy-id" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../../../../../../modules/memorystore-valkey"
}

locals {
  # Get instance name from folder name
  _path_components = split("/", path_relative_to_include())
  instance_name    = local._path_components[length(local._path_components) - 1]
}

inputs = {
  project_id              = include.root.locals.project_id
  instance_id             = local.instance_name
  location                = include.root.locals.region
  engine_version          = "VALKEY_8_0"
  network                 = format("%s-%s", include.root.locals.environment, include.root.locals.project)
  node_type               = "SHARED_CORE_NANO"
  shard_count             = 1
  replica_count           = 0
  authorization_mode      = "IAM_AUTH"
  transit_encryption_mode = "SERVER_AUTHENTICATION"
  labels                  = include.root.locals.labels

  engine_configs = {
    "maxmemory-policy" = local.instance_name
  }

  deletion_protection_enabled = false # Set to true for production
}

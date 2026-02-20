include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "memorystore_valkey" {
  path = "${get_repo_root()}/modules/gcp/memorystore-valkey/terragrunt.hcl"
}

dependency "scp" {
  config_path = "../../service-connection-policy/valkey-psc"

  mock_outputs = {
    policy_ids = { "valkey-psc" = "mock-policy-id" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

locals {
  instance_name = "${basename(get_terragrunt_dir())}-${include.root.locals.region_short}"
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
    "maxmemory-policy" = basename(get_terragrunt_dir())
  }

  deletion_protection_enabled = false # Set to true for production
}

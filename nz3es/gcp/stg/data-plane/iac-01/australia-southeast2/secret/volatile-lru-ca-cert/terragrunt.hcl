include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "secret_manager" {
  path = "${get_repo_root()}/modules/gcp/secret-manager/terragrunt.hcl"
}

dependency "valkey" {
  config_path = "../../memorystore/volatile-lru"

  mock_outputs = {
    valkey_cluster = {
      managed_server_ca = [
        {
          ca_certs = [
            {
              certificates = ["mock-ca-cert"]
            }
          ]
        }
      ]
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

locals {
  secret_name = "${basename(get_terragrunt_dir())}-${include.root.locals.region_short}"
}

inputs = {
  project_id  = include.root.locals.project_id
  name        = local.secret_name
  secret_data = join("\n", dependency.valkey.outputs.valkey_cluster.managed_server_ca[0].ca_certs[0].certificates)
  # secret_data = "mock-ca-cert"
  labels = include.root.locals.labels
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "dns_zone" {
  path = "${get_repo_root()}/modules/gcp/dns-zone/terragrunt.hcl"
}

dependency "network" {
  config_path = "../../network"

  mock_outputs = {
    network_self_link = "mock-network-self-link"
    network_id        = "mock-network-id"
    subnets           = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# dependency "valkey" {
#   config_path = "../../../australia-southeast2/memorystore/volatile-lru"

#   mock_outputs = {
#     endpoints = [
#       {
#         connections = [
#           {
#             psc_auto_connection = [
#               {
#                 connection_type = "CONNECTION_TYPE_DISCOVERY"
#                 ip_address      = "10.0.0.1"
#               }
#             ]
#           }
#         ]
#       }
#     ]
#   }
#   mock_outputs_allowed_terraform_commands = ["validate", "plan"]
# }

locals {
  zone_name = basename(get_terragrunt_dir())
  domain    = "${replace(local.zone_name, "-", ".")}."
}

inputs = {
  project_id  = include.root.locals.project_id
  name        = local.zone_name
  domain      = local.domain
  description = "Private DNS zone for ${include.root.locals.environment}"
  type        = "private"

  private_visibility_config_networks = [dependency.network.outputs.network_self_link]

  recordsets = [
    {
      name    = "app"
      type    = "A"
      ttl     = 300
      records = ["10.1.0.10"]
    },
    {
      name    = "db"
      type    = "A"
      ttl     = 300
      records = ["10.1.0.20"]
    },
    # {
    #   name = "volatile-lru"
    #   type = "A"
    #   ttl  = 300
    #   records = flatten([
    #     for endpoint in dependency.valkey.outputs.endpoints : [
    #       for conn in endpoint.connections : [
    #         for psc in conn.psc_auto_connection :
    #         psc.ip_address
    #         if psc.connection_type == "CONNECTION_TYPE_DISCOVERY"
    #       ]
    #     ]
    #   ])
    # },
  ]
}

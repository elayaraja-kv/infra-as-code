include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
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

dependency "valkey" {
  config_path = "../../../australia-southeast2/memorystore/volatile-lru"

  mock_outputs = {
    endpoints = [
      {
        connections = [
          {
            psc_auto_connection = [
              {
                connection_type = "CONNECTION_TYPE_DISCOVERY"
                ip_address      = "10.0.0.1"
              }
            ]
          }
        ]
      }
    ]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../../../../../../modules/dns-zone"
}

locals {
  # Get zone name from folder name
  _path_components = split("/", path_relative_to_include())
  zone_name        = local._path_components[length(local._path_components) - 1]
  dns_name         = "${replace(local.zone_name, "-", ".")}."
}

inputs = {
  project_id  = include.root.locals.project_id
  name        = local.zone_name
  dns_name    = local.dns_name
  description = "Private DNS zone for ${include.root.locals.environment}"
  visibility  = "private"

  private_visibility_networks = [dependency.network.outputs.network_self_link]

  records = {
    "app" = {
      type    = "A"
      ttl     = 300
      rrdatas = ["10.1.0.10"]
    },
    "db" = {
      type    = "A"
      ttl     = 300
      rrdatas = ["10.1.0.20"]
    },
    "volatile-lru" = {
      type    = "A"
      ttl     = 300
      rrdatas = flatten([
        for endpoint in dependency.valkey.outputs.endpoints : [
          for conn in endpoint.connections : [
            for psc in conn.psc_auto_connection :
            psc.ip_address
            if psc.connection_type == "CONNECTION_TYPE_DISCOVERY"
          ]
        ]
      ])
    },
  }
}

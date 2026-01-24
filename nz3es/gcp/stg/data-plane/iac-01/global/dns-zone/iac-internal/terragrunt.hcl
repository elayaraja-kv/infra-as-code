include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "network" {
  config_path = "../../network"
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
  }
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "dns_zone" {
  path = "${get_repo_root()}/modules/gcp/dns-zone/terragrunt.hcl"
}

locals {
  zone_name = basename(get_terragrunt_dir())
  domain    = "${replace(local.zone_name, "-", ".")}."
}

inputs = {
  project_id  = include.root.locals.project_id
  name        = local.zone_name
  domain      = local.domain
  description = "Public DNS zone for ${include.root.locals.environment}"
  type        = "public"

  recordsets = [
    # {
    #   name    = "app"
    #   type    = "A"
    #   ttl     = 300
    #   records = ["10.2.0.10"]
    # },
    # {
    #   name    = "db"
    #   type    = "A"
    #   ttl     = 300
    #   records = ["10.2.0.20"]
    # },
  ]
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../../../../../../../modules/service-connection-policy"
}

inputs = {
  project_id    = include.root.locals.project_id
  location      = include.root.locals.region
  service_class = "gcp-memorystore"

  policies = {
    "valkey-psc" = {
      network_name = format("%s-%s", include.root.locals.environment, include.root.locals.project)
      subnet_names = include.root.locals.subnets
    }
  }
}

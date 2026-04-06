include "root" {
  path   = find_in_parent_folders("root-gcp.hcl")
  expose = true
}

include "cloud_sql_postgres" {
  path = "${get_repo_root()}/modules/gcp/cloud-sql-postgres/terragrunt.hcl"
}

locals {
  instance_name = "${basename(dirname(get_terragrunt_dir()))}-${basename(get_terragrunt_dir())}-${include.root.locals.region_short}"
}

inputs = {
  project_id = include.root.locals.project_id
  name       = local.instance_name
  region     = include.root.locals.region
  tier       = "db-f1-micro" # 1 shared vCPU, 614 MB RAM — upgrade for production

  ip_configuration = {
    ipv4_enabled                                  = false
    enable_private_path_for_google_cloud_services = true
    private_network                               = null
    allocated_ip_range                            = null
    authorized_networks                           = []
    psc_enabled                                   = true
    psc_allowed_consumer_projects                 = [include.root.locals.project_id]
  }

  database_flags = [
    {
      name  = "max_connections"
      value = "100"
    }
  ]

  user_labels = include.root.locals.labels

  additional_databases = [
    {
      name      = "users"
      charset   = "UTF8"
      collation = "en_US.UTF8"
    }
  ]

  additional_users = [
    {
      name            = "users-owner"
      password        = null
      random_password = true
      type            = "BUILT_IN"
    },
    {
      name            = "users-reader"
      password        = null
      random_password = true
      type            = "BUILT_IN"
    }
  ]
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "secret_manager" {
  path = "${get_repo_root()}/modules/gcp/secret-manager/terragrunt.hcl"
}

locals {
  secret_name = "${basename(get_terragrunt_dir())}-${include.root.locals.region_short}"
}

inputs = {
  project_id  = include.root.locals.project_id
  name        = local.secret_name
  secret_data = jsonencode({
    ORG_DEPLOY_TOKEN = get_env("ORG_DEPLOY_TOKEN", "ghp_xxxx")
    NPM_TOKEN        = get_env("NPM_TOKEN", "npm_xxxx")
    API_KEYS         = get_env("API_KEYS", "KEY1=xxxx;KEY2=yyyy")
  })
  labels      = include.root.locals.labels
}

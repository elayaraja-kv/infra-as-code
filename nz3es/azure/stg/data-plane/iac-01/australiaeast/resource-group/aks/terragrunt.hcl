include "root" {
  path   = find_in_parent_folders("root-azure.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//modules/azure/resource-group"
}

inputs = {
  name     = "rg-${basename(get_terragrunt_dir())}-${include.root.locals.environment}-${include.root.locals.project}-${include.root.locals.region_short}"
  location = include.root.locals.region
  tags     = include.root.locals.tags
}

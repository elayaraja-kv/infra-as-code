include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/modules/service-account"
}

locals {
  _path_components = split("/", path_relative_to_include())
  sa_name          = local._path_components[length(local._path_components) - 1]
}

inputs = {
  project_id   = include.root.locals.project_id
  name         = local.sa_name
  display_name = "GKE Node Service Account - ${local.sa_name}"
  roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ]
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "service_account" {
  path = "${get_repo_root()}/modules/gcp/service-account/terragrunt.hcl"
}

locals {
  sa_name = basename(get_terragrunt_dir())
}

inputs = {
  project_id   = include.root.locals.project_id
  names        = [local.sa_name]
  display_name = "GKE Node Service Account - ${local.sa_name}"
  project_roles = [
    "${include.root.locals.project_id}=>roles/logging.logWriter",
    "${include.root.locals.project_id}=>roles/monitoring.metricWriter",
    "${include.root.locals.project_id}=>roles/monitoring.viewer",
    "${include.root.locals.project_id}=>roles/stackdriver.resourceMetadata.writer",
    "${include.root.locals.project_id}=>roles/artifactregistry.reader",
    # Cross-project: Artifact Registry on iac-02
    # "iac-02=>roles/artifactregistry.reader",
  ]
}

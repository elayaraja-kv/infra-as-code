include "root" {
  path   = find_in_parent_folders("root-gcp.hcl")
  expose = true
}

include "service_account" {
  path = "${get_repo_root()}/modules/gcp/service-account/terragrunt.hcl"
}

locals {
  sa_name   = basename(get_terragrunt_dir()) # "github-runner"
  namespace = "arc-runners"                  # ARC runner scale set namespace
  ksa_name  = "nz3es-runner"                 # ARC scale set name = KSA name
}

# Workload Identity binding: ARC runner KSA → GCP SA
generate "workload_identity_binding" {
  path      = "workload_identity_binding.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    resource "google_service_account_iam_member" "workload_identity" {
      service_account_id = "projects/${include.root.locals.project_id}/serviceAccounts/${local.sa_name}@${include.root.locals.project_id}.iam.gserviceaccount.com"
      role               = "roles/iam.workloadIdentityUser"
      member             = "serviceAccount:${include.root.locals.project_id}.svc.id.goog[${local.namespace}/${local.ksa_name}]"

      depends_on = [google_service_account.service_accounts]
    }
  EOF
}

# Allows github-runner SA to impersonate the automation SA in CI workflows.
# Usage in workflow: gcloud auth print-access-token \
#   --impersonate-service-account=nz3es-automation-sa@iac-01.iam.gserviceaccount.com
generate "automation_sa_impersonation" {
  path      = "automation_sa_impersonation.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    resource "google_service_account_iam_member" "impersonate_automation_sa" {
      service_account_id = "projects/${include.root.locals.project_id}/serviceAccounts/nz3es-automation-sa@${include.root.locals.project_id}.iam.gserviceaccount.com"
      role               = "roles/iam.serviceAccountTokenCreator"
      member             = "serviceAccount:${local.sa_name}@${include.root.locals.project_id}.iam.gserviceaccount.com"

      depends_on = [google_service_account.service_accounts]
    }
  EOF
}

inputs = {
  project_id   = include.root.locals.project_id
  names        = [local.sa_name]
  display_name = "Workload Identity SA for ARC GitHub runner"

  # No direct project roles — runner impersonates nz3es-automation-sa for GCP access.
  project_roles = []
}

include "root" {
  path   = find_in_parent_folders("root-gcp.hcl")
  expose = true
}

include "service_account" {
  path = "${get_repo_root()}/modules/gcp/service-account/terragrunt.hcl"
}

locals {
  sa_name = basename(get_terragrunt_dir())  # "github-runner-vm"
}

# Allows the runner VM to read the GitHub App private key from Secret Manager at boot.
# Other GCP access (terraform, gcloud) is done via impersonation of nz3es-automation-sa.
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
  display_name = "Service Account for GitHub runner VM"

  project_roles = [
    # Read GitHub App key from Secret Manager at VM startup
    "${include.root.locals.project_id}=>roles/secretmanager.secretAccessor",
    # Write logs and metrics to Cloud Operations
    "${include.root.locals.project_id}=>roles/logging.logWriter",
    "${include.root.locals.project_id}=>roles/monitoring.metricWriter",
  ]
}

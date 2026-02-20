include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "service_account" {
  path = "${get_repo_root()}/modules/gcp/service-account/terragrunt.hcl"
}

locals {
  sa_name   = basename(get_terragrunt_dir())  # "external-dns"
  namespace = basename(get_terragrunt_dir())  # k8s namespace (matches SA name)
}

# Generates the Workload Identity IAM binding as a plain google provider resource.
# No kubernetes provider needed — KSA is created and annotated by Helm in k8s-as-code.
generate "workload_identity_binding" {
  path      = "workload_identity_binding.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    resource "google_service_account_iam_member" "workload_identity" {
      service_account_id = "projects/${include.root.locals.project_id}/serviceAccounts/${local.sa_name}@${include.root.locals.project_id}.iam.gserviceaccount.com"
      role               = "roles/iam.workloadIdentityUser"
      member             = "serviceAccount:${include.root.locals.project_id}.svc.id.goog[${local.namespace}/${local.sa_name}]"

      depends_on = [google_service_account.service_accounts]
    }
  EOF
}

inputs = {
  project_id   = include.root.locals.project_id
  names        = [local.sa_name]
  display_name = "Workload Identity SA for ${local.sa_name}"

  project_roles = [
    "${include.root.locals.project_id}=>roles/dns.admin",
  ]
}

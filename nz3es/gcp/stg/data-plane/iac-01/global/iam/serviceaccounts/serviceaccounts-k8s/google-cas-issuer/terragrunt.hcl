include "root" {
  path   = find_in_parent_folders("root-gcp.hcl")
  expose = true
}

include "workload_identity" {
  path = "${get_repo_root()}/modules/gcp/workload-identity/terragrunt.hcl"
}

locals {
  sa_name      = basename(get_terragrunt_dir())  # GCP SA name: "google-cas-issuer"
  namespace    = basename(get_terragrunt_dir())  # k8s namespace: "google-cas-issuer"
  k8s_sa_name  = "cert-manager-google-cas-issuer"  # actual KSA name created by the Helm chart
  base_path = "${get_repo_root()}/${include.root.locals.org}/${include.root.locals.provider}/${include.root.locals.environment}/${include.root.locals.plane}/${include.root.locals.project}"
}

dependency "private_ca" {
  config_path = "${local.base_path}/australia-southeast2/private-ca/linkerd"

  mock_outputs = {
    ca_pool_name     = "mock-ca-pool"
    ca_pool_location = "australia-southeast2"
    ca_pool_id       = "projects/mock-project/locations/australia-southeast2/caPools/mock-ca-pool"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# CA pool IAM is resource-scoped (not project-level), so it can't use the
# workload-identity module's `roles` input — generate it as a separate resource.
generate "ca_pool_iam" {
  path      = "ca_pool_iam.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    variable "ca_pool_id" {}

    resource "google_privateca_ca_pool_iam_member" "cas_requester" {
      project  = "${include.root.locals.project_id}"
      ca_pool  = var.ca_pool_id
      role     = "roles/privateca.certificateRequester"
      member   = "serviceAccount:${local.sa_name}@${include.root.locals.project_id}.iam.gserviceaccount.com"
    }
  EOF
}

inputs = {
  name       = local.sa_name
  namespace  = local.namespace
  project_id = include.root.locals.project_id
  ca_pool_id = dependency.private_ca.outputs.ca_pool_id

  # The Helm chart creates the KSA named "cert-manager-google-cas-issuer" (not sa_name).
  # k8s_sa_name overrides the WI binding to use the correct KSA.
  k8s_sa_name         = local.k8s_sa_name
  use_existing_k8s_sa = true
  annotate_k8s_sa     = false

  # CA pool IAM is resource-scoped — handled by the generate block above.
  roles = []
}

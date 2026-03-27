# Linkerd trust anchor — public root CA certificate (Option A: local CA).
#
# This is the PUBLIC cert only — safe to manage here.
# The matching private key is in secret/linkerd-trust-anchor-key (managed separately).
#
# The cert content is also committed in:
#   k8s-as-code/addons/linkerd/values-stg.yaml (identityTrustAnchorsPEM)
#
# If the secret already exists (created manually), import it first:
#   cd nz3es/gcp/stg/data-plane/iac-01/australia-southeast2/secret/linkerd-trust-anchor-cert
#   terragrunt import 'google_secret_manager_secret.secret' \
#     projects/iac-01/secrets/linkerd-trust-anchor-cert

include "root" {
  path   = find_in_parent_folders("root-gcp.hcl")
  expose = true
}

include "secret_manager" {
  path = "${get_repo_root()}/modules/gcp/secret-manager/terragrunt.hcl"
}

inputs = {
  project_id  = include.root.locals.project_id
  name        = "linkerd-trust-anchor-cert"
  secret_data = get_env("LINKERD_TRUST_ANCHOR_CERT", "PLACEHOLDER")
  labels      = include.root.locals.labels
}

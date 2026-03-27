# Linkerd trust anchor — PRIVATE root CA key (Option A: local CA).
#
# SENSITIVE: The key value must never be committed to Git.
# Set LINKERD_TRUST_ANCHOR_KEY env var from GCP Secret Manager before applying:
#
#   export LINKERD_TRUST_ANCHOR_KEY=$(gcloud secrets versions access latest \
#     --secret=linkerd-trust-anchor-key --project=<project-id>)
#   terragrunt apply
#
# Generate once (if not already done):
#   openssl ecparam -name prime256v1 -genkey -noout -out ca.key
#   openssl req -new -x509 -key ca.key \
#     -subj "/O=cluster.local/CN=root.linkerd.cluster.local" \
#     -days 3650 -extensions v3_ca -out ca.crt
#   export LINKERD_TRUST_ANCHOR_KEY=$(cat ca.key)
#   export LINKERD_TRUST_ANCHOR_CERT=$(cat ca.crt)
#   terragrunt apply   # in both this dir and ../linkerd-trust-anchor-cert
#   rm ca.key ca.crt
#
# If the secret already exists (created manually), import it first:
#   terragrunt import 'google_secret_manager_secret.secret' \
#     projects/iac-01/secrets/linkerd-trust-anchor-key

include "root" {
  path   = find_in_parent_folders("root-gcp.hcl")
  expose = true
}

include "secret_manager" {
  path = "${get_repo_root()}/modules/gcp/secret-manager/terragrunt.hcl"
}

inputs = {
  project_id  = include.root.locals.project_id
  name        = "linkerd-trust-anchor-key"
  secret_data = get_env("LINKERD_TRUST_ANCHOR_KEY", "PLACEHOLDER")
  labels      = include.root.locals.labels
}

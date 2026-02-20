terraform {
  source = "tfr:///terraform-google-modules/kubernetes-engine/google//modules/workload-identity?version=43.0.0"
}

# Default inputs — override from individual workload-identity terragrunt.hcl
#
# Required inputs (no defaults — must be set per instance):
#   name         - name for both GCP SA and KSA (GCP SA truncated to 30 chars)
#   project_id   - GCP project ID
#
# Outputs:
#   gcp_service_account_email  - GCP SA email (use for IAM bindings)
#   k8s_service_account_name   - KSA name
#   k8s_service_account_namespace
#   gcp_service_account_fqn
#   gcp_service_account_name
#   gcp_service_account        - full GCP SA resource
#
# Note: KSA annotation requires gcloud + kubectl access at apply time.
# Use use_existing_gcp_sa=true / use_existing_k8s_sa=true to bind existing accounts.
inputs = {
  namespace                       = "default"
  use_existing_gcp_sa             = false
  use_existing_k8s_sa             = false
  annotate_k8s_sa                 = true
  automount_service_account_token = false
  roles                           = []
  additional_projects             = {}
}

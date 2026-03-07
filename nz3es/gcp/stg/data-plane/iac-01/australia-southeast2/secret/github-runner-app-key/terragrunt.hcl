# GitHub App private key for ARC (Actions Runner Controller).
#
# SENSITIVE: The key value must never be committed to Git.
# Set GITHUB_RUNNER_APP_KEY env var before applying:
#
#   export GITHUB_RUNNER_APP_KEY=$(cat /path/to/github-app.private-key.pem)
#   terragrunt apply
#
# Generate by creating a GitHub App at:
#   https://github.com/organizations/<org>/settings/apps
# Required permissions: Actions (R/W), Administration (R/W)
#
# If the secret already exists (created manually), import it first:
#   terragrunt import 'google_secret_manager_secret.secret' \
#     projects/iac-01/secrets/github-runner-app-key

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "secret_manager" {
  path = "${get_repo_root()}/modules/gcp/secret-manager/terragrunt.hcl"
}

inputs = {
  project_id  = include.root.locals.project_id
  name        = "github-runner-app-key"
  secret_data = get_env("GITHUB_RUNNER_APP_KEY", "PLACEHOLDER")
  labels      = include.root.locals.labels
}

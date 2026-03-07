include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "compute_instance" {
  path = "${get_repo_root()}/modules/gcp/compute-instance/terragrunt.hcl"
}

locals {
  base_path = "${get_repo_root()}/${include.root.locals.org}/${include.root.locals.provider}/${include.root.locals.environment}/${include.root.locals.plane}/${include.root.locals.project}"

  # GitHub App config — install the App on nz3es org to get the org installation ID
  github_org                 = "nz3es"
  github_app_id              = "3030666"
  github_app_installation_id = "<REPLACE_WITH_ORG_INSTALLATION_ID>"
  github_app_key_secret      = "github-runner-app-key"

  # Tool versions
  runner_version     = "2.321.0"
  terraform_version  = "1.14.6"
  terragrunt_version = "0.99.4"

  startup_script = <<-SCRIPT
    #!/bin/bash
    set -euo pipefail

    PROJECT_ID="${include.root.locals.project_id}"
    GITHUB_ORG="${local.github_org}"
    GITHUB_APP_ID="${local.github_app_id}"
    GITHUB_APP_INSTALLATION_ID="${local.github_app_installation_id}"
    SECRET_NAME="${local.github_app_key_secret}"
    RUNNER_NAME="$(hostname)"
    RUNNER_LABELS="self-hosted,linux,x64,stg,vm,org"
    RUNNER_VERSION="${local.runner_version}"
    TERRAFORM_VERSION="${local.terraform_version}"
    TERRAGRUNT_VERSION="${local.terragrunt_version}"

    log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a /var/log/runner-setup.log; }

    log "=== GitHub runner setup start ==="

    # --- Base dependencies ---
    log "Installing base dependencies..."
    apt-get update -q
    apt-get install -y -q git curl jq unzip docker.io openssl apt-transport-https ca-certificates gnupg

    # --- Google Cloud SDK ---
    log "Installing gcloud..."
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      > /etc/apt/sources.list.d/google-cloud-sdk.list
    apt-get update -q
    apt-get install -y -q google-cloud-sdk google-cloud-sdk-gke-gcloud-auth-plugin kubectl

    # --- Terraform ---
    log "Installing terraform $${TERRAFORM_VERSION}..."
    curl -sL "https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip" \
      -o /tmp/terraform.zip
    unzip -q /tmp/terraform.zip -d /usr/local/bin/
    chmod +x /usr/local/bin/terraform
    rm /tmp/terraform.zip

    # --- Terragrunt ---
    log "Installing terragrunt $${TERRAGRUNT_VERSION}..."
    curl -sL "https://github.com/gruntwork-io/terragrunt/releases/download/v$${TERRAGRUNT_VERSION}/terragrunt_linux_amd64" \
      -o /usr/local/bin/terragrunt
    chmod +x /usr/local/bin/terragrunt

    # --- Runner user ---
    log "Creating runner user..."
    useradd -m -s /bin/bash -G docker runner 2>/dev/null || true
    RUNNER_HOME=/home/runner
    mkdir -p "$${RUNNER_HOME}/actions-runner"

    # --- Download GitHub runner ---
    log "Downloading runner $${RUNNER_VERSION}..."
    curl -sL "https://github.com/actions/runner/releases/download/v$${RUNNER_VERSION}/actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz" \
      | tar -xz -C "$${RUNNER_HOME}/actions-runner"
    chown -R runner:runner "$${RUNNER_HOME}"

    # --- GitHub App → runner registration token ---
    generate_jwt() {
      local private_key="$1" app_id="$2"
      local now=$(date +%s)
      local header=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
      local payload=$(echo -n "{\"iat\":$((now-60)),\"exp\":$((now+600)),\"iss\":\"$${app_id}\"}" \
                       | base64 -w0 | tr '+/' '-_' | tr -d '=')
      local sig=$(echo -n "$${header}.$${payload}" \
                   | openssl dgst -sha256 -sign <(echo "$${private_key}") \
                   | base64 -w0 | tr '+/' '-_' | tr -d '=')
      echo "$${header}.$${payload}.$${sig}"
    }

    log "Fetching GitHub App private key from Secret Manager..."
    PRIVATE_KEY=$(gcloud secrets versions access latest \
      --secret="$${SECRET_NAME}" --project="$${PROJECT_ID}")

    log "Generating runner registration token..."
    JWT=$(generate_jwt "$${PRIVATE_KEY}" "$${GITHUB_APP_ID}")

    INSTALLATION_TOKEN=$(curl -sS -X POST \
      -H "Authorization: Bearer $${JWT}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/app/installations/$${GITHUB_APP_INSTALLATION_ID}/access_tokens" \
      | jq -r '.token')

    REG_TOKEN=$(curl -sS -X POST \
      -H "Authorization: Bearer $${INSTALLATION_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/orgs/$${GITHUB_ORG}/actions/runners/registration-token" \
      | jq -r '.token')

    # --- Configure runner ---
    log "Configuring runner as $${RUNNER_NAME}..."
    cd "$${RUNNER_HOME}/actions-runner"
    sudo -u runner ./config.sh \
      --url "https://github.com/$${GITHUB_ORG}" \
      --token "$${REG_TOKEN}" \
      --name "$${RUNNER_NAME}" \
      --labels "$${RUNNER_LABELS}" \
      --unattended \
      --replace

    # --- Systemd service ---
    log "Installing runner as systemd service..."
    ./svc.sh install runner
    ./svc.sh start

    log "=== GitHub runner setup complete ==="
  SCRIPT
}

dependency "sa" {
  config_path = "${local.base_path}/global/iam/serviceaccounts/github-runner-vm"

  mock_outputs = {
    email = "github-runner-vm@mock-project.iam.gserviceaccount.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  project_id = include.root.locals.project_id
  name       = "github-runner-org-stg"
  region     = include.root.locals.region
  zone       = "${include.root.locals.region}-a"

  machine_type = "e2-standard-2"
  disk_size_gb = 50

  # compute-ause2 subnet, no external IP — outbound via Cloud NAT
  subnetwork = "projects/${include.root.locals.project_id}/regions/${include.root.locals.region}/subnetworks/compute-ause2"

  service_account_email = dependency.sa.outputs.email

  startup_script = local.startup_script

  labels = include.root.locals.labels
  tags   = ["github-runner"]
}

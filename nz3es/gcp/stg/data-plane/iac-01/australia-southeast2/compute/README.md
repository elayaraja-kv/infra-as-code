# Self-Hosted GitHub Actions Runners

Two VM-based runners on GCP — one scoped to a personal repo, one to a GitHub org.

## Architecture

```
GitHub Actions job
  └─ dispatches to self-hosted runner (VM in GCP, no external IP)
       ├─ outbound via Cloud NAT (australia-southeast2/cloud-nat)
       ├─ GitHub App private key from Secret Manager
       └─ systemd service keeps runner alive across reboots
```

---

## Prerequisites

### 1. GitHub App

A single GitHub App (`app_id = 3030666`) is used for both runners.

**Required permissions (Repository and/or Organization):**

| Permission | Level | Required for |
|---|---|---|
| `Administration` | Read & Write | Runner registration |
| `Actions` | Read & Write | Trigger / manage workflows |

**Setup steps:**
1. Go to GitHub → Settings → Developer settings → GitHub Apps → your app
2. Ensure the above permissions are granted
3. Generate a private key (`.pem`) if not already done
4. Store the PEM in GCP Secret Manager:
   ```bash
   gcloud secrets versions add github-runner-app-key \
     --data-file=/path/to/private-key.pem \
     --project=<project_id>
   ```

---

## Personal Account Runner (repo-level)

**Unit:** `australia-southeast2/compute/github-runner/`

**Scope:** `elayaraja-kv/infra-as-code` repo only

**Runner labels:** `self-hosted, linux, x64, stg, vm`

### Installation ID

The App is installed on the personal account. Installation ID: `114630061`

To verify: GitHub → Settings → Applications → Installed GitHub Apps → your app → the URL contains the installation ID.

### Apply

```bash
cd nz3es/gcp/stg/data-plane/iac-01/australia-southeast2/compute/github-runner
terragrunt apply
```

### Use in workflow

```yaml
jobs:
  deploy:
    runs-on: [self-hosted, linux, stg, vm]
    steps:
      - uses: actions/checkout@v4
      - run: terragrunt plan
```

---

## Org Runner

**Unit:** `australia-southeast2/compute/github-runner-org/`

**Scope:** `nz3es` org — available to all repos in the org

**Runner labels:** `self-hosted, linux, x64, stg, vm, org`

### Installation ID

1. Go to your GitHub App → **Install App** → select `nz3es` org → Install
2. After install, navigate to:
   `https://github.com/organizations/nz3es/settings/installations`
3. Click your app — the URL will contain the installation ID:
   `https://github.com/organizations/nz3es/settings/installations/XXXXXXXXX`
4. Update `github_app_installation_id` in `github-runner-org/terragrunt.hcl`

### Apply

```bash
cd nz3es/gcp/stg/data-plane/iac-01/australia-southeast2/compute/github-runner-org
terragrunt apply
```

### Use in workflow

```yaml
jobs:
  deploy:
    runs-on: [self-hosted, linux, stg, vm, org]
    steps:
      - uses: actions/checkout@v4
      - run: terragrunt plan
```

---

## Apply Order

Apply units in this order (dependencies flow downward):

```
1. global/network                                    (subnet: compute-ause2)
2. global/iam/serviceaccounts/github-runner-vm       (VM service account)
3. australia-southeast2/secret/github-runner-app-key (GitHub App private key)
4. australia-southeast2/compute/github-runner         (personal repo runner)
5. australia-southeast2/compute/github-runner-org     (org runner)
```

---

## Verifying Runner Registration

After `terragrunt apply`, the VM boots and the startup script runs (~3–5 min).

**Personal repo runner:**
`https://github.com/elayaraja-kv/infra-as-code/settings/actions/runners`

**Org runner:**
`https://github.com/organizations/nz3es/settings/actions/runners`

The runner status should show **Idle** when ready.

---

## Debugging

Startup script logs are written to `/var/log/runner-setup.log` on the VM.

Access via IAP (no external IP on VM):
```bash
gcloud compute ssh <instance-name> \
  --tunnel-through-iap \
  --zone=australia-southeast2-a \
  --project=<project_id>

# Then on the VM:
sudo cat /var/log/runner-setup.log
sudo systemctl status actions.runner.*
```

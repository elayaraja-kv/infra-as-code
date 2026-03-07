# GitHub Actions Workflows

## Overview

| Workflow | Trigger | Runner | Blocks merge? |
| --- | --- | --- | --- |
| `runner-test.yml` | Manual (`workflow_dispatch`) | self-hosted | No |
| `terragrunt-ci.yml` | Push (any branch) | self-hosted | No |
| `terragrunt-lint.yml` | Pull request | ubuntu-latest | No (advisory) |
| `security-scan.yml` | Pull request + push to main | ubuntu-latest | No (advisory) |

---

## runner-test.yml

Smoke test for the self-hosted VM runner. Verifies all tools are installed and GCP auth is working.

**Trigger:** Manual only — go to Actions → Runner Test → Run workflow.

**Checks:**

- Hostname, OS, user
- `terraform`, `terragrunt`, `gcloud`, `docker`, `kubectl` versions
- `gcloud auth list` (confirms VM SA is attached)

---

## terragrunt-ci.yml

Validates only the terragrunt units that changed in a commit. Runs on every push.

**Steps:**

1. Detect changed `.tf` / `.hcl` files and find their unit directories
2. `terraform fmt -check -recursive` — formatting check
3. `terragrunt hcl validate` — HCL syntax check (no init needed)
4. `terragrunt init && terragrunt validate` — per changed unit only
5. If `modules/` changed → `terragrunt hcl validate` across all units

**Key config:**

```yaml
TF_CLI_ARGS_init: "-backend=false"   # skips GCS backend — no state access needed
```

---

## terragrunt-lint.yml

Static analysis on pull requests. Advisory only — does not block merge.

**Tools:**

- `terraform fmt -check` — canonical formatting
- `tflint` with GCP plugin — best practices, invalid args, deprecated syntax

**Config file:** `.tflint.hcl` at repo root (enables GCP plugin v0.30.0).

---

## security-scan.yml

IaC security scanning on pull requests and pushes to `main`. Advisory only — does not block merge.

### Tools

#### Trivy

- Scans all `.tf` and `.hcl` files for misconfigurations
- Rules based on CIS benchmarks and GCP-specific policies
- Severity filter: `CRITICAL`, `HIGH`, `MEDIUM`
- Output: SARIF → uploaded to **Security → Code scanning** tab

#### Checkov

- Broader policy checks: networking, IAM, encryption, logging, public exposure
- Framework: `terraform`
- Output: SARIF → uploaded to **Security → Code scanning** tab

### Viewing results

Results appear in the **Security** tab → **Code scanning** after the first run.

Each finding shows:
- Rule ID and description
- File path and line number
- Severity level
- Link to remediation docs

### Known behaviour

- Both tools use `continue-on-error: true` and `soft_fail: true` — failures are reported but never block the PR
- SARIF upload is guarded with `hashFiles()` — skipped if the scan produces no output file
- Trivy runs as CLI (not the GitHub Action) for reliable SARIF file creation

### Interpreting findings

Not every finding requires immediate action. Common categories in IaC repos:

| Category | Example | Action |
| --- | --- | --- |
| Logging disabled | GCS bucket access logs off | Fix if in scope |
| Encryption | Disk not CMEK encrypted | Fix if compliance required |
| Public exposure | Resource open to `0.0.0.0/0` | Fix if unintentional |
| IAM over-permission | Broad roles assigned | Review and tighten |
| False positive | Test/dev resource flagged | Suppress with inline comment |

To suppress a false positive in Terraform:

```hcl
#trivy:ignore:AVD-GCP-XXXX
#checkov:skip=CKV_GCP_XXX:Reason for skipping
resource "google_compute_instance" "example" {
  ...
}
```

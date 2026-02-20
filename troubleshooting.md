# Troubleshooting Commands

## Terragrunt / Terraform

### Terragrunt v0.99+ command changes

Flags and commands were renamed in v0.99. Old flags are no longer recognised.

| Old (pre-v0.99) | New (v0.99+) |
| --- | --- |
| `terragrunt run-all apply` | `terragrunt run --all apply` |
| `terragrunt run-all plan` | `terragrunt run --all plan` |
| `terragrunt run-all destroy` | `terragrunt run --all destroy` |
| `--terragrunt-working-dir <path>` | `--working-dir <path>` |
| `--terragrunt-non-interactive` | `--non-interactive` |

### Apply / plan a single unit

```bash
# From repo root
terragrunt apply --working-dir <path/to/unit>
terragrunt plan  --working-dir <path/to/unit>

# Example
terragrunt apply --working-dir nz3es/gcp/stg/data-plane/iac-01/global/iam/serviceaccounts/gke-cluster
```

### Apply / plan across all units in a folder

```bash
# From repo root
terragrunt run --all apply --working-dir <path/to/folder>
terragrunt run --all plan  --working-dir <path/to/folder>

# Example — all dns-zone units
terragrunt run --all apply --working-dir nz3es/gcp/stg/data-plane/iac-01/global/dns-zone
```

### Initialize and validate a single unit

```bash
terragrunt init     --working-dir <path/to/unit>
terragrunt validate --working-dir <path/to/unit>
```

### Run across all modules

```bash
cd nz3es/gcp/stg/data-plane/iac-01
terragrunt run --all init
terragrunt run --all plan
```

### Clear terragrunt cache

```bash
find $HOME/git/infra-as-code -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null; echo "Done - removed all .terragrunt-cache directories"

find $HOME/git/infra-as-code -type f -name ".terraform.lock.hcl" -exec rm -rf {} + 2>/dev/null; echo "Done - removed all .terraform.lock.hcl files"

```

### GKE cluster inspection

```bash
gcloud container clusters list --project=iac-01
gcloud container clusters describe stg-iac-01-ause2 --project=iac-01

gcloud container node-pools list --cluster=stg-iac-01-ause2 --region=australia-southeast2 --project=iac-01

gcloud container node-pools describe nz3es-spot-pool --cluster=stg-iac-01-ause2 --region=australia-southeast2 --project=iac-01 | yq .config.labels
# cluster_name: stg-iac-01-ause2
# node_pool: nz3es-spot-pool
# nz3es/dedicated: 'true'
```

### Check GKE operation status

Operation IDs appear in:

- `terragrunt apply` output (e.g. `operation-1234567890123-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)
- `gcloud container operations list` output

```bash
# List recent operations
gcloud container operations list --region australia-southeast2 --project iac-01

# Describe a specific operation
gcloud container operations describe <operation_id> --region australia-southeast2 --project iac-01 | grep status
# status: DONE
```

### k8s

```bash
k get events --sort-by=.lastTimestamp
k get events -w --field-selector involvedObject.kind=Pod
```

### Re-initialize with upgrade

```bash
terragrunt init -upgrade
```

## Memorystore Valkey Deprecation Fixes

### Issue: `desired_psc_auto_connections` deprecated

The upstream module (terraform-google-modules/memorystore) uses the deprecated `desired_psc_auto_connections` parameter.

**Fix:** Use `google_memorystore_instance` resource directly with `desired_auto_created_endpoints`:

```hcl
resource "google_memorystore_instance" "valkey" {
  # ... other config ...

  desired_auto_created_endpoints {
    network    = "projects/${var.project_id}/global/networks/${var.network}"
    project_id = var.project_id
  }
}
```

### Issue: `discovery_endpoints` output deprecated

**Fix:** Remove the deprecated output and use `endpoints` instead.

### Issue: Duplicate required_providers

When using terragrunt's `generate "provider"` block, don't add a separate `versions.tf` in modules.

**Fix:** Remove `versions.tf` from the module if root.hcl generates provider configuration.

## Google Provider Version

The `desired_auto_created_endpoints` parameter requires Google provider >= 6.0.0:

```hcl
google = {
  source  = "hashicorp/google"
  version = ">= 6.0.0"
}
```

## GKE Node Scheduling

### Issue: Pod with toleration lands on wrong node pool

A pod with only a `toleration` for `nz3es/dedicated` will **not** be forced onto spot nodes. Tolerations only allow a pod to be scheduled on tainted nodes — they don't prevent scheduling on untainted nodes.

**Fix:** Add a `nodeSelector` alongside the toleration to force scheduling onto spot nodes:

```yaml
spec:
  nodeSelector:
    nz3es/dedicated: "true"
  tolerations:
    - key: "nz3es/dedicated"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
```

- **Toleration** = "I'm allowed to run on spot nodes" (removes the taint barrier)
- **nodeSelector** = "I must run on spot nodes" (directs scheduling)

### Issue: Pod with spot nodeSelector lands on NAP-created pool instead of manual spot pool

When using `nodeSelector: nz3es/dedicated: "true"` with NAP enabled, the pod may land on a NAP-created spot pool (e.g. `nap-e2-standard-2-spot`) instead of your manually defined `nz3es-spot-pool`. This happens because `nz3es/dedicated` matches **any** spot node, and NAP creates its own pool before the manual pool scales up (especially when `min_count = 0`).

**Fix:** Use `cloud.google.com/gke-nodepool` to target a specific node pool:

```yaml
spec:
  nodeSelector:
    cloud.google.com/gke-nodepool: "nz3es-spot-pool"
  tolerations:
    - key: "nz3es/dedicated"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
```

GKE automatically labels every node with `cloud.google.com/gke-nodepool=<pool-name>`. This directs the scheduler to scale up the specific manual pool rather than letting NAP create a new one.

### Issue: NAP creates unexpected node with system pods

When `cluster_autoscaling.enabled = true` and `enable_default_compute_class = true`, GKE creates a `ComputeClass` named "autopilot". System workloads (`gke-managed-cim/kube-state-metrics`, `gmp-system/collector`, `gmp-system/gmp-operator`) carry a nodeSelector for this compute class, causing NAP to auto-provision a node for them.

**Fix:** Set `enable_default_compute_class = false` if you don't want NAP provisioning nodes for system pods. They will then schedule on your manual node pools instead.

### Issue: Maintenance window error — 48h availability

```text
Error 400: maintenance policy would go longer than 32d without 48h maintenance availability
```

GKE requires at least 48 hours of maintenance availability per 32-day rolling window.

**Fix:** Use at least two days in the recurrence (e.g. `BYDAY=SA,SU` instead of just `BYDAY=SA`):

```hcl
maintenance_start_time = "2025-01-01T15:00:00Z"
maintenance_end_time   = "2025-01-01T21:00:00Z"
maintenance_recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
```

Note: `maintenance_start_time` and `maintenance_end_time` require full RFC3339 format (`2025-01-01T15:00:00Z`), not just `HH:MM`.

## Useful Links

- [Memorystore Valkey Terraform Module Issue #314](https://github.com/terraform-google-modules/terraform-google-memorystore/issues/314)
- [Google Memorystore Instance Resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/memorystore_instance)

# GCP Infrastructure — Claude Context

## Path Convention

```text
{org}/gcp/{env}/{plane}/{project}/{region}/{component}/{instance}/
```

- Path components parsed automatically by `root-gcp.hcl` into locals: `org`, `provider`, `environment`, `plane`, `project`, `region`, `component`
- Use `get_repo_root()` for all module paths — never relative `../../`
- Use `find_in_parent_folders("root-gcp.hcl")` for root include

## Naming Convention

Resource names derived at runtime — never hardcode env or region in folder names:

```hcl
# Instance name pattern (e.g. GKE cluster)
name = "${basename(get_terragrunt_dir())}-${include.root.locals.region_short}"
# stg-iac-01 folder + ause2 region → stg-iac-01-ause2

# Service account name
name = basename(get_terragrunt_dir())
```

Labels auto-applied from `root-gcp.hcl` path locals: `org`, `environment`, `plane`, `project`, `region`, `component`, `managed_by`.

## Region Short Names (`root-gcp.hcl`)

| Region | Short |
| ------ | ----- |
| `australia-southeast1` | `ause1` |
| `australia-southeast2` | `ause2` |
| `us-central1` | `usc1` |
| `europe-west1` | `euw1` |
| `global` | `gbl` |

## Module Patterns

### Upstream (tfr://)

```hcl
terraform {
  source = "tfr:///terraform-google-modules/kubernetes-engine/google//modules/private-cluster?version=44.0.0"
}
```

### Custom (local Terraform module)

```hcl
terraform {
  source = "${get_repo_root()}//modules/gcp/compute-instance"
}
```

### Module wrapper include

```hcl
include "gke" {
  path = "${get_repo_root()}/modules/gcp/gke-private-cluster/terragrunt.hcl"
}
```

### Optional feature include

```hcl
include "allow_net_admin" {
  path = "${get_repo_root()}/modules/gcp/gke-private-cluster/features/allow_net_admin.hcl"
}
```

## Dependency Pattern

```hcl
dependency "network" {
  config_path = "${local.base_path}/global/network"
  mock_outputs = { network_name = "mock-network" }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}
```

Always provide `mock_outputs` for `validate` and `plan` to avoid needing a full apply chain.

## Service Account Pattern (Decoupled WI)

- **infra-as-code**: creates GCP SA + IAM roles + Workload Identity binding (`generate` block)
- **k8s-as-code**: KSA + annotation (`iam.gke.io/gcp-service-account`) via Helm values
- `generate` block resource must have `depends_on = [google_service_account.service_accounts]`

## GKE Key Defaults (`modules/gcp/gke-private-cluster`)

- Upstream: `terraform-google-modules/kubernetes-engine/google//modules/private-cluster v44.0.0`
- `enable_private_nodes = true`, `enable_private_endpoint = false`
- `remove_default_node_pool = true`, `create_service_account = false`
- NAP disabled (`enabled = false`) + `enable_default_compute_class = true` for autopilot ComputeClass
- Spot pools: `spot = true` in node_pools map
- `node_pools_taints` always requires `all = []` baseline

## State Backend

- GCS bucket: `nz3es-tf-state-iac` (region: `australia-southeast2`)
- Key: `infra-as-code/{path_relative_to_include()}`
- Auth: `GOOGLE_APPLICATION_CREDENTIALS` env var

## Common Gotchas

- `maintenance_start_time` needs full RFC3339 (`2025-01-01T15:00:00Z`), not `HH:MM`
- Maintenance recurrence needs `BYDAY=SA,SU` (not just `SA`) for 48h/32-day requirement
- NAP `max_cpu_cores`/`max_memory_gb` are cluster-wide (includes manual + NAP pools)
- Default compute class is a namespace **label** (`kubectl label`), not annotation
- Private GKE nodes need Cloud NAT for outbound internet (image pulls, Helm downloads)
- `subnet_private_access = true` only covers Google APIs, not Docker Hub / quay.io

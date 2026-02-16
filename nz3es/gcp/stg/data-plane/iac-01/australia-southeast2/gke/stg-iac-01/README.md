# GKE Autopilot ComputeClass - Custom SA Workaround

Upstream module [v43.0](https://github.com/terraform-google-modules/terraform-google-kubernetes-engine) gates `auto_provisioning_defaults` (SA, oauth scopes) behind `enabled=true`. When `enabled=false` + `enable_default_compute_class=true`, autopilot nodes fall back to the default compute SA.

## Option A: `after_hook` + `sed` patch (Recommended)

Patches upstream `cluster.tf` after `terraform init` to include `enable_default_compute_class` in the `for_each` condition. The hook uses `commands = ["init"]` so it runs after the module is downloaded. It's idempotent — skips patching if the file already contains the fix.

- **Pros:** Native Terraform state tracking, drift detection, idempotent, no external deps
- **Cons:** Re-patches after every init, fragile if upstream changes the `for_each` line format
- **Note:** Hook runs inside `.terragrunt-cache/` — uses `find` with fallback to locate `cluster.tf`

## Option B: `generate` + `null_resource` REST API

Generates a `null_resource` that sets the SA via GKE REST API (`PUT` with `ClusterUpdate`) after cluster creation. Uses `curl -sf` (silent + fail-on-error) instead of checking `%{http_code}`, which conflicts with HCL template syntax in `generate` blocks.

- **Pros:** No upstream code modification, version-agnostic, works regardless of module internals
- **Cons:** No drift detection, depends on `gcloud auth` at apply time, not fully declarative
- **Note:** Terragrunt `generate` adds an extra HCL processing layer — `${}` and `%{}` are interpreted as interpolation/template directives (avoid bare `%{...}` in generated content)

## Why PUT, not PATCH?

The GKE REST API (`projects.locations.clusters.update`) only supports `PUT` with a `ClusterUpdate` body — there is no `PATCH` endpoint for cluster updates. Despite being a `PUT`, it behaves like a partial update: only the `desired*` fields in the `ClusterUpdate` object are applied, other cluster settings are left unchanged. This is by design in the GKE API (unlike typical REST semantics where `PUT` replaces the entire resource).

Ref: [clusters.update](https://cloud.google.com/kubernetes-engine/docs/reference/rest/v1/projects.locations.clusters/update)

---

Both options are temporary until upstream fixes the `for_each` condition or GCP supports setting the SA independently.

# GKE Autopilot ComputeClass - Custom SA Workaround

Upstream module [v43.0](https://github.com/terraform-google-modules/terraform-google-kubernetes-engine) gates `auto_provisioning_defaults` (SA, oauth scopes) behind `enabled=true`. When `enabled=false` + `enable_default_compute_class=true`, autopilot nodes fall back to the default compute SA.

## Option A: `after_hook` + `sed` patch (Recommended)

Patches upstream `cluster.tf` after init to include `enable_default_compute_class` in the `for_each` condition.

- **Pros:** Native Terraform state tracking, drift detection, idempotent, no external deps
- **Cons:** Re-patches after every init, fragile if upstream changes line format

## Option B: `generate` + `null_resource` REST API

Generates a `null_resource` that sets the SA via GKE REST API after cluster creation.

- **Pros:** No upstream code modification, version-agnostic
- **Cons:** No drift detection, depends on gcloud auth at apply time, not declarative

Both are temporary until upstream fixes the `for_each` condition or GCP supports setting the SA independently.

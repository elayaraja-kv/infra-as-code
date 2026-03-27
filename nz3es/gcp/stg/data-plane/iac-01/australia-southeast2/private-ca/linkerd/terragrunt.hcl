# GCP Certificate Authority Service pool for Linkerd — Option B only.
#
# NOTE: This is NOT used in the current setup (Option A: local CA via cert-manager).
# Switch to Option B (GCP CAS) requires:
#   - ENTERPRISE tier (DEVOPS tier cannot issue isCA:true certificates required by Linkerd)
#   - google-cas-issuer addon enabled in addons-prereqs.yaml
#   - linkerd-identity-issuer.yaml updated to use GoogleCASClusterIssuer
#
# See k8s-as-code/addons/linkerd/README.md for full Option B setup.

include "root" {
  path   = find_in_parent_folders("root-gcp.hcl")
  expose = true
}

terraform {
  source = "../../../../../../../../modules/gcp/private-ca"
}

inputs = {
  project_id = include.root.locals.project_id
  location   = include.root.locals.region

  pool_name = "linkerd-${include.root.locals.environment}"
  ca_id     = "linkerd-root-${include.root.locals.environment}"

  common_name  = "root.linkerd.cluster.local"
  organization = "cluster.local"

  # ENTERPRISE tier required — DEVOPS tier cannot issue isCA:true certificates (Linkerd identity issuer)
  # NOTE: Changing tier requires destroy + recreate (set deletion_protection=false first)
  tier                  = "ENTERPRISE"
  ca_lifetime           = "315360000s" # 10 years
  maximum_cert_lifetime = "172800s"    # 48h — matches Linkerd issuer cert duration
  deletion_protection   = false
}

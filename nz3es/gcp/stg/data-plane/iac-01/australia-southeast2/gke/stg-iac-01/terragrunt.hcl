include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "gke" {
  path = "${get_repo_root()}/modules/gcp/gke-private-cluster/terragrunt.hcl"
}

locals {
  cluster_name = "${basename(get_terragrunt_dir())}-${include.root.locals.region_short}"
  base_path    = "${get_repo_root()}/${include.root.locals.org}/${include.root.locals.provider}/${include.root.locals.environment}/${include.root.locals.plane}/${include.root.locals.project}"
}

dependency "network" {
  config_path = "${local.base_path}/global/network"

  mock_outputs = {
    network_self_link = "mock-network-self-link"
    network_id        = "mock-network-id"
    subnets           = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "service_account" {
  config_path = "${local.base_path}/global/iam/serviceaccounts/gke-cluster"

  mock_outputs = {
    email = "mock-gke-sa@project.iam.gserviceaccount.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# ---------------------------------------------------------------------------
# Option A: after_hook
# Patches upstream cluster.tf so the autoprovisioningNodePoolDefaults block
# (which carries the custom SA) is created when enable_default_compute_class
# is true, even if NAP (cluster_autoscaling.enabled) is false.
# ---------------------------------------------------------------------------
# generate "patch_compute_class" {
#   path      = "patch_compute_class.sh"
#   if_exists = "overwrite_terragrunt"
#   contents  = <<-EOF
#     #!/usr/bin/env bash
#     set -euo pipefail

#     echo "Running patch_compute_class.sh in $(pwd)"
#     if [[ "$(pwd)" != */private-cluster ]] || [ ! -f cluster.tf ]; then
#       echo "Not in private-cluster directory or no cluster.tf found, skipping"
#       exit 0
#     fi

#     if grep -q 'enable_default_compute_class.*\[1\]' cluster.tf; then
#       echo "Already patched"
#       exit 0
#     fi

#     echo "Patching cluster.tf"
#     sed -i.bak 's#for_each = var\.cluster_autoscaling\.enabled ? \[1\] : \[\]#for_each = var.cluster_autoscaling.enabled || lookup(var.cluster_autoscaling, "enable_default_compute_class", false) ? [1] : []#' cluster.tf

#     if grep -q 'enable_default_compute_class.*\[1\]' cluster.tf; then
#       rm -f cluster.tf.bak
#       echo "Patch applied successfully"
#     else
#       echo "Patch failed"
#       exit 1
#     fi
#   EOF
# }

# terraform {
#   after_hook "patch_compute_class_sa" {
#     commands = ["init"]
#     execute  = ["bash", "patch_compute_class.sh"]
#   }
# }


# ---------------------------------------------------------------------------
# Option B: generate block (active)
# Sets SA via REST API after cluster creation.
# With tfr:// source, use var.name instead of module.gke.name since the
# upstream module runs as root module (no wrapper).
# ---------------------------------------------------------------------------
generate "compute_class_sa" {
  path      = "compute_class_sa.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    resource "null_resource" "compute_class_service_account" {
      count = (!var.cluster_autoscaling.enabled &&
        lookup(var.cluster_autoscaling, "enable_default_compute_class", false) &&
        var.service_account != "") ? 1 : 0

      triggers = {
        service_account = var.service_account
        cluster_name    = var.name
      }

      provisioner "local-exec" {
        command = <<-EOT
          TOKEN=$(gcloud auth print-access-token) && \
          curl -sf -X PUT \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"update":{"desiredClusterAutoscaling":{"autoprovisioningNodePoolDefaults":{"serviceAccount":"$${var.service_account}","oauthScopes":["https://www.googleapis.com/auth/cloud-platform"]}}}}' \
            "https://container.googleapis.com/v1/projects/$${var.project_id}/locations/$${var.region}/clusters/$${var.name}" \
            && echo "SA patched successfully" \
            || (echo "Failed to patch SA" && exit 1)
        EOT
      }

      depends_on = [google_container_cluster.primary, google_container_node_pool.pools]
    }
  EOF
}

inputs = {
  project_id = include.root.locals.project_id
  name       = local.cluster_name
  region     = include.root.locals.region
  network    = format("%s-%s", include.root.locals.environment, include.root.locals.project)
  subnetwork = include.root.locals.region_short

  # Secondary ranges
  ip_range_pods     = "gke-pods"
  ip_range_services = "gke-services"

  # Private cluster
  enable_private_nodes    = true
  enable_private_endpoint = false

  master_authorized_networks = concat(
    [
      {
        cidr_block   = "${get_env("GKE_MASTER_CIDR", "125.237.27.134/32")}"
        display_name = "nz3es-home"
      },
      {
        cidr_block   = "${get_env("GKE_MASTER_CIDR_1", "10.1.0.0/24")}"
        display_name = "nz3es-additional-1"
      },
    ],
    get_env("GKE_MASTER_CIDR_2", "") != "" ? [
      {
        cidr_block   = get_env("GKE_MASTER_CIDR_2", "")
        display_name = "nz3es-additional-2"
      }
    ] : [],
  )

  # Node pools (default node pool will be removed and replaced with custom node pools)
  remove_default_node_pool = true
  initial_node_count       = 0

  cluster_autoscaling = {
    enabled                      = false
    autoscaling_profile          = "OPTIMIZE_UTILIZATION"
    gpu_resources                = []
    auto_repair                  = true
    auto_upgrade                 = true
    enable_default_compute_class = true
  }

  node_pools = [
    {
      name               = "nz3es-pool"
      machine_type       = "e2-medium"
      initial_node_count = 0
      total_min_count    = 0
      total_max_count    = 6
      max_surge          = 2
      max_unavailable    = 3
      disk_size_gb       = 100
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
    },
    {
      name               = "nz3es-spot-pool"
      machine_type       = "e2-medium"
      initial_node_count = 0
      total_min_count    = 0
      total_max_count    = 10
      max_surge          = 2
      max_unavailable    = 3
      disk_size_gb       = 100
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
      spot               = true
    }
  ]

  node_pools_labels = {
    all = {}
    nz3es-spot-pool = {
      "nz3es/dedicated" = "true"
    }
  }

  node_pools_taints = {
    all = []
    nz3es-spot-pool = [
      {
        key    = "nz3es/dedicated"
        value  = "true"
        effect = "NO_SCHEDULE"
      }
    ]
  }

  # Cluster config
  kubernetes_version      = "1.34"
  release_channel         = "REGULAR"
  cluster_resource_labels = include.root.locals.labels
  deletion_protection     = false # Set to true for production
  datapath_provider       = "ADVANCED_DATAPATH"

  # Security
  security_posture_mode                  = "BASIC"
  security_posture_vulnerability_mode    = "VULNERABILITY_BASIC"
  enable_binary_authorization            = false # Set to true for production
  insecure_kubelet_readonly_port_enabled = false

  # Maintenance window (Sat-Sun 3:00 AM - 9:00 AM NZST)
  maintenance_start_time = "2025-01-01T15:00:00Z" # 3:00 AM NZST (UTC+12)
  maintenance_end_time   = "2025-01-01T21:00:00Z" # 9:00 AM NZST (UTC+12)
  maintenance_recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"

  # Best practice
  enable_vertical_pod_autoscaling = true
  enable_intranode_visibility     = true
  enable_cost_allocation          = true

  # Service account
  create_service_account = false
  service_account        = dependency.service_account.outputs.email

  # Addons
  dns_cache                            = true
  gateway_api_channel                  = "CHANNEL_STANDARD"
  monitoring_enable_managed_prometheus = true

  # Logging & Monitoring components
  logging_enabled_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  monitoring_enabled_components = [
    "SYSTEM_COMPONENTS", "STORAGE", "POD", "DEPLOYMENT",
    "STATEFULSET", "DAEMONSET", "HPA", "JOBSET",
    "CADVISOR", "KUBELET", "DCGM",
  ]
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  _path_components = split("/", path_relative_to_include())
  cluster_name     = local._path_components[length(local._path_components) - 1]
  base_path        = "${get_repo_root()}/${include.root.locals.org}/${include.root.locals.provider}/${include.root.locals.environment}/${include.root.locals.plane}/${include.root.locals.project}"
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

terraform {
  source = "${get_repo_root()}/modules/gke-private-cluster"
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
    enabled                      = true
    autoscaling_profile          = "OPTIMIZE_UTILIZATION"
    min_cpu_cores                = 0
    max_cpu_cores                = 16
    min_memory_gb                = 0
    max_memory_gb                = 64
    gpu_resources                = []
    auto_repair                  = true
    auto_upgrade                 = true
    enable_default_compute_class = true
  }

  node_pools = [
    {
      name               = "nz3es-pool"
      machine_type       = "e2-medium"
      initial_node_count = 1
      min_count          = 1
      max_count          = 3
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
      min_count          = 0
      max_count          = 2
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
  kubernetes_version  = "1.34"
  release_channel     = "REGULAR"
  labels              = include.root.locals.labels
  deletion_protection = false # Set to true for production
  datapath_provider   = "ADVANCED_DATAPATH"

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

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "network" {
  config_path = "../../../global/network"

  mock_outputs = {
    network_self_link = "mock-network-self-link"
    network_id        = "mock-network-id"
    subnets           = {}
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "../../../../../../../../modules/gke-private-cluster"
}

locals {
  _path_components = split("/", path_relative_to_include())
  cluster_name     = local._path_components[length(local._path_components) - 1]
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
  enable_private_nodes    = false
  enable_private_endpoint = false

  master_authorized_networks = []

  # Node pools
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
      initial_node_count = 1
      min_count          = 0
      max_count          = 1
      disk_size_gb       = 100
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
    }
  ]

  # Cluster config
  kubernetes_version  = "1.33"
  release_channel     = "REGULAR"
  labels              = include.root.locals.labels
  deletion_protection = false # Set to true for production
  datapath_provider   = "ADVANCED_DATAPATH"

  # Service account
  create_service_account = false

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

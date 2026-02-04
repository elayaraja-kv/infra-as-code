module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 43.0"

  project_id = var.project_id
  name       = var.name
  region     = var.region
  network    = var.network
  subnetwork = var.subnetwork

  # IP ranges
  ip_range_pods     = var.ip_range_pods
  ip_range_services = var.ip_range_services

  # Private cluster
  enable_private_nodes         = var.enable_private_nodes
  enable_private_endpoint      = var.enable_private_endpoint
  master_ipv4_cidr_block       = var.master_ipv4_cidr_block
  master_global_access_enabled = var.master_global_access_enabled
  master_authorized_networks   = var.master_authorized_networks

  # Node pools
  remove_default_node_pool = var.remove_default_node_pool
  initial_node_count       = var.initial_node_count
  node_pools               = var.node_pools
  node_pools_labels        = var.node_pools_labels
  node_pools_tags          = var.node_pools_tags

  # Cluster config
  kubernetes_version     = var.kubernetes_version
  release_channel        = var.release_channel
  cluster_resource_labels = var.labels
  deletion_protection    = var.deletion_protection
  datapath_provider      = var.datapath_provider

  # Addons
  http_load_balancing                 = var.http_load_balancing
  horizontal_pod_autoscaling          = var.horizontal_pod_autoscaling
  gce_pd_csi_driver                   = var.gce_pd_csi_driver
  dns_cache                           = var.dns_cache
  gateway_api_channel                 = var.gateway_api_channel
  monitoring_enable_managed_prometheus = var.monitoring_enable_managed_prometheus

  # Logging & Monitoring
  logging_enabled_components    = var.logging_enabled_components
  monitoring_enabled_components = var.monitoring_enabled_components

  # Autoscaling
  cluster_autoscaling = var.cluster_autoscaling

  # Service account
  create_service_account = var.create_service_account
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster"
  type        = string
}

variable "network" {
  description = "VPC network name"
  type        = string
}

variable "subnetwork" {
  description = "Subnetwork name"
  type        = string
}

variable "ip_range_pods" {
  description = "Name of the secondary IP range for pods"
  type        = string
}

variable "ip_range_services" {
  description = "Name of the secondary IP range for services"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the hosted master network"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "List of CIDRs allowed to access the master endpoint"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "node_pools" {
  description = "List of node pool configurations"
  type        = list(map(any))
  default = [
    {
      name         = "default-pool"
      machine_type = "e2-medium"
      min_count    = 1
      max_count    = 3
      disk_size_gb = 50
      disk_type    = "pd-standard"
      image_type   = "COS_CONTAINERD"
      auto_repair  = true
      auto_upgrade = true
    }
  ]
}

variable "node_pools_labels" {
  description = "Labels for node pools keyed by pool name"
  type        = map(map(string))
  default     = {}
}

variable "node_pools_tags" {
  description = "Network tags for node pools keyed by pool name"
  type        = map(list(string))
  default     = {}
}

variable "kubernetes_version" {
  description = "Kubernetes version for the master and nodes"
  type        = string
  default     = "latest"
}

variable "release_channel" {
  description = "Release channel: UNSPECIFIED, RAPID, REGULAR, STABLE"
  type        = string
  default     = "REGULAR"
}

variable "labels" {
  description = "Labels to apply to the cluster"
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = true
}

variable "remove_default_node_pool" {
  description = "Remove the default node pool"
  type        = bool
  default     = true
}

variable "initial_node_count" {
  description = "Initial number of nodes in the default node pool"
  type        = number
  default     = 0
}

variable "enable_private_nodes" {
  description = "Nodes get internal IPs only"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Master only accessible via internal IP"
  type        = bool
  default     = false
}

variable "master_global_access_enabled" {
  description = "Whether the master is globally accessible"
  type        = bool
  default     = true
}

variable "http_load_balancing" {
  description = "Enable HTTP load balancing addon"
  type        = bool
  default     = true
}

variable "horizontal_pod_autoscaling" {
  description = "Enable horizontal pod autoscaling"
  type        = bool
  default     = true
}

variable "gce_pd_csi_driver" {
  description = "Enable GCE PD CSI Driver"
  type        = bool
  default     = true
}

variable "dns_cache" {
  description = "Enable NodeLocal DNSCache addon"
  type        = bool
  default     = false
}

variable "gateway_api_channel" {
  description = "Gateway API channel: null, CHANNEL_DISABLED, CHANNEL_EXPERIMENTAL, CHANNEL_STANDARD"
  type        = string
  default     = null
}

variable "monitoring_enable_managed_prometheus" {
  description = "Enable Google Cloud Managed Service for Prometheus"
  type        = bool
  default     = false
}

variable "logging_enabled_components" {
  description = "List of GKE components to enable logging for"
  type        = list(string)
  default     = []
}

variable "monitoring_enabled_components" {
  description = "List of GKE components to enable monitoring for"
  type        = list(string)
  default     = []
}

variable "datapath_provider" {
  description = "Datapath provider (DATAPATH_PROVIDER_UNSPECIFIED or ADVANCED_DATAPATH for Dataplane V2)"
  type        = string
  default     = "ADVANCED_DATAPATH"
}

variable "create_service_account" {
  description = "Create a dedicated service account for nodes"
  type        = bool
  default     = true
}

variable "cluster_autoscaling" {
  description = "Cluster autoscaling configuration (NAP - Node Auto-Provisioning)"
  type = object({
    enabled                      = bool
    autoscaling_profile          = string
    min_cpu_cores                = optional(number)
    max_cpu_cores                = optional(number)
    min_memory_gb                = optional(number)
    max_memory_gb                = optional(number)
    gpu_resources                = list(object({ resource_type = string, minimum = number, maximum = number }))
    auto_repair                  = bool
    auto_upgrade                 = bool
    disk_size                    = optional(number)
    disk_type                    = optional(string)
    image_type                   = optional(string)
    strategy                     = optional(string)
    max_surge                    = optional(number)
    max_unavailable              = optional(number)
    node_pool_soak_duration      = optional(string)
    batch_soak_duration          = optional(string)
    batch_percentage             = optional(number)
    batch_node_count             = optional(number)
    enable_secure_boot           = optional(bool, false)
    enable_integrity_monitoring  = optional(bool, true)
    enable_default_compute_class = optional(bool, false)
  })
  default = {
    enabled             = false
    autoscaling_profile = "BALANCED"
    min_cpu_cores       = 0
    max_cpu_cores       = 0
    min_memory_gb       = 0
    max_memory_gb       = 0
    gpu_resources       = []
    auto_repair         = true
    auto_upgrade        = true
    disk_size           = 100
    disk_type           = "pd-standard"
    image_type          = "COS_CONTAINERD"
  }
}

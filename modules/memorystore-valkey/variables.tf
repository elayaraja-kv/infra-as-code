variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "instance_id" {
  description = "ID for the Valkey instance (4-63 chars, lowercase letters/digits/hyphens)"
  type        = string
}

variable "location" {
  description = "GCP region where Valkey cluster will be created"
  type        = string
}

variable "network" {
  description = "Name of the consumer network for the discovery endpoint"
  type        = string
}

variable "node_type" {
  description = "Node type: SHARED_CORE_NANO, HIGHMEM_MEDIUM, HIGHMEM_XLARGE, STANDARD_SMALL"
  type        = string
  default     = "SHARED_CORE_NANO"
}

variable "shard_count" {
  description = "Number of shards for the instance"
  type        = number
  default     = 1
}

variable "replica_count" {
  description = "Number of replica nodes per shard"
  type        = number
  default     = 0
}

variable "labels" {
  description = "Labels to apply to the instance"
  type        = map(string)
  default     = {}
}

variable "engine_version" {
  description = "Valkey engine version"
  type        = string
  default     = "VALKEY_8_0"
}

variable "deletion_protection_enabled" {
  description = "If true, deletion of the instance will fail"
  type        = bool
  default     = true
}

variable "authorization_mode" {
  description = "Authorization mode: AUTH_DISABLED or IAM_AUTH"
  type        = string
  default     = "AUTH_DISABLED"
}

variable "transit_encryption_mode" {
  description = "In-transit encryption: TRANSIT_ENCRYPTION_DISABLED or SERVER_AUTHENTICATION"
  type        = string
  default     = "TRANSIT_ENCRYPTION_DISABLED"
}

variable "engine_configs" {
  description = "User-provided engine configurations (e.g., maxmemory-policy)"
  type        = map(string)
  default     = {}
}

variable "service_connection_policies" {
  description = "Service Connection Policies for PSC"
  type = map(object({
    subnet_names    = list(string)
    network_name    = string
    network_project = optional(string)
    limit           = optional(number)
    labels          = optional(map(string))
    description     = optional(string)
  }))
  default = {}
}

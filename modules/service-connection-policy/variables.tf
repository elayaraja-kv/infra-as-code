variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "GCP region for the service connection policy"
  type        = string
}

variable "service_class" {
  description = "Service class for the connection policy (e.g., gcp-memorystore)"
  type        = string
}

variable "policies" {
  description = "Map of service connection policies to create"
  type = map(object({
    subnet_names    = list(string)
    network_name    = string
    network_project = optional(string)
    limit           = optional(number)
    labels          = optional(map(string))
    description     = optional(string)
  }))
}

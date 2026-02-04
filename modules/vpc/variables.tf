variable "name" {
  description = "Name for the VPC"
  type        = string
}

variable "project_id" {
  description = "GCP project id"
  type        = string
}

variable "subnets" {
  description = "Map of subnets to create"
  type = map(object({
    region = string
    cidr   = string
    secondary_ip_ranges = optional(list(object({
      range_name    = string
      ip_cidr_range = string
    })), [])
  }))
  default = {}
}


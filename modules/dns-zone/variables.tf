variable "name" {
  description = "Name of the DNS zone"
  type        = string
}

variable "dns_name" {
  description = "DNS name (e.g., example.com.)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "visibility" {
  description = "Zone visibility: public or private"
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.visibility)
    error_message = "Visibility must be 'public' or 'private'."
  }
}

variable "private_visibility_networks" {
  description = "List of VPC network self links for private zones"
  type        = list(string)
  default     = []
}

variable "description" {
  description = "Description of the DNS zone"
  type        = string
  default     = ""
}

variable "records" {
  description = "Map of DNS record sets to create"
  type = map(object({
    type    = string
    ttl     = number
    rrdatas = list(string)
  }))
  default = {}
}

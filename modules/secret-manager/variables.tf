variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "secret_id" {
  description = "Secret ID in Secret Manager"
  type        = string
}

variable "secret_data" {
  description = "Secret data to store"
  type        = string
  sensitive   = true
}

variable "labels" {
  description = "Labels to apply to the secret"
  type        = map(string)
  default     = {}
}

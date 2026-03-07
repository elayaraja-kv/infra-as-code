variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name" {
  description = "Instance name (also used as hostname and template name prefix)"
  type        = string
}

variable "region" {
  description = "GCP region (e.g. australia-southeast2)"
  type        = string
}

variable "zone" {
  description = "GCP zone (e.g. australia-southeast2-a)"
  type        = string
}

variable "machine_type" {
  description = "Compute machine type"
  type        = string
  default     = "e2-standard-2"
}

variable "image_family" {
  description = "Boot disk image family"
  type        = string
  default     = "ubuntu-2404-lts-amd64"
}

variable "image_project" {
  description = "Project hosting the boot image"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "subnetwork" {
  description = "Subnetwork self-link or name"
  type        = string
}

variable "service_account_email" {
  description = "Service account email to attach to the instance"
  type        = string
}

variable "startup_script" {
  description = "Startup script content"
  type        = string
  default     = ""
}

variable "labels" {
  description = "Labels to apply to the instance"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags"
  type        = list(string)
  default     = []
}

variable "project_id" {
  type        = string
  description = "Project where the PSC endpoint (address + forwarding rule) is created"
}

variable "name" {
  type        = string
  description = "Name for the reserved address and forwarding rule"
}

variable "region" {
  type        = string
  description = "Region for the PSC endpoint"
}

variable "network" {
  type        = string
  description = "Self link of the consumer VPC network"
}

variable "subnetwork" {
  type        = string
  description = "Name or self link of the consumer subnetwork the endpoint address is reserved from"
}

variable "target_service_attachment" {
  type        = string
  description = "Self link of the producer's PSC service attachment to connect to (e.g. Cloud SQL psc_service_attachment_link)"
}

variable "ip_address" {
  type        = string
  default     = null
  description = "Static internal IP to reserve for the endpoint. Leave null to let GCP auto-assign from the subnetwork"
}

variable "allow_psc_global_access" {
  type        = bool
  default     = false
  description = "Allow the PSC endpoint to be reached from other regions"
}

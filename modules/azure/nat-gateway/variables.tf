variable "resource_group_name" {
  type        = string
  description = "Name of the resource group."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "name" {
  type        = string
  description = "CAF name for the NAT gateway (ng- prefix)."
}

variable "public_ip_name" {
  type        = string
  description = "CAF name for the public IP (pip- prefix)."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs to associate with the NAT gateway."
}

variable "sku" {
  type        = string
  default     = "Standard"
  description = "SKU for the public IP and NAT gateway."
}

variable "idle_timeout_in_minutes" {
  type        = number
  default     = 4
  description = "Idle timeout for NAT gateway connections (minutes)."
}

variable "zones" {
  type        = list(string)
  default     = ["1"]
  description = "Availability zones for the public IP."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources."
}

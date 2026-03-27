variable "resource_group_name" {
  description = "Name of the resource group to create the managed identity in."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "name" {
  description = "Name of the user-assigned managed identity."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "role_assignments" {
  description = <<-EOT
    List of role assignments to create for this identity.
    Each object requires:
      scope                - full ARM resource ID or subscription/RG scope
      role_definition_name - built-in role name (e.g. "AcrPull", "Network Contributor")
  EOT
  type = list(object({
    scope                = string
    role_definition_name = string
  }))
  default = []
}

variable "federated_credentials" {
  description = <<-EOT
    Workload Identity federated credentials (OIDC).
    Used to allow a Kubernetes Service Account to impersonate this identity.
    Each object requires:
      name      - unique name for the credential
      issuer    - OIDC issuer URL from the AKS cluster (oidc_issuer_url output)
      subject   - system:serviceaccount:{namespace}:{ksa-name}
      audiences - list of audiences (default: ["api://AzureADTokenExchange"])
  EOT
  type = list(object({
    name      = string
    issuer    = string
    subject   = string
    audiences = optional(list(string), ["api://AzureADTokenExchange"])
  }))
  default = []
}

output "id" {
  description = "Resource ID of the user-assigned managed identity."
  value       = azurerm_user_assigned_identity.this.id
}

output "principal_id" {
  description = "Object (principal) ID — used for role assignments and AAD group membership."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "client_id" {
  description = "Client ID — used in Workload Identity annotations on Kubernetes Service Accounts."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "name" {
  description = "Name of the managed identity."
  value       = azurerm_user_assigned_identity.this.name
}

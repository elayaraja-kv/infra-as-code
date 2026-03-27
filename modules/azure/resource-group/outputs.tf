output "name" {
  description = "Resource group name."
  value       = azurerm_resource_group.this.name
}

output "id" {
  description = "Resource group resource ID."
  value       = azurerm_resource_group.this.id
}

output "location" {
  description = "Azure region the resource group was created in."
  value       = azurerm_resource_group.this.location
}

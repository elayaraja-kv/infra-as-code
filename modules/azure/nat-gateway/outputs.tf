output "nat_gateway_id" {
  value       = azurerm_nat_gateway.this.id
  description = "ID of the NAT gateway."
}

output "public_ip_address" {
  value       = azurerm_public_ip.this.ip_address
  description = "Public IP address of the NAT gateway."
}

output "public_ip_id" {
  value       = azurerm_public_ip.this.id
  description = "Resource ID of the public IP."
}

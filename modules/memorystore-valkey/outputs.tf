output "id" {
  description = "ID of the Valkey instance"
  value       = module.valkey.id
}

output "endpoints" {
  description = "Endpoints of the Valkey instance"
  value       = module.valkey.endpoints
}

output "valkey_cluster" {
  description = "Full Valkey cluster resource"
  value       = module.valkey.valkey_cluster
}

output "ca_cert" {
  description = "CA certificate for TLS connections (populated when transit encryption is SERVER_AUTHENTICATION)"
  value       = try(module.valkey.valkey_cluster.managed_server_ca[0].ca_certs[0].certificates, null)
  sensitive   = true
}

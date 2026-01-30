output "policies" {
  description = "Map of created service connection policies"
  value       = google_network_connectivity_service_connection_policy.policy
}

output "policy_ids" {
  description = "Map of policy names to their IDs"
  value = {
    for k, v in google_network_connectivity_service_connection_policy.policy : k => v.id
  }
}

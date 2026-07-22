output "ip_address" {
  value       = google_compute_address.psc_endpoint.address
  description = "The private IP address reserved for the PSC endpoint"
}

output "forwarding_rule_self_link" {
  value       = google_compute_forwarding_rule.psc_endpoint.self_link
  description = "Self link of the PSC endpoint forwarding rule"
}

output "forwarding_rule_id" {
  value       = google_compute_forwarding_rule.psc_endpoint.id
  description = "ID of the PSC endpoint forwarding rule"
}

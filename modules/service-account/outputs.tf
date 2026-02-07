output "email" {
  description = "Service account email"
  value       = google_service_account.this.email
}

output "id" {
  description = "Service account ID"
  value       = google_service_account.this.id
}

output "name" {
  description = "Service account name"
  value       = google_service_account.this.name
}

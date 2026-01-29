output "secret_id" {
  description = "Secret ID"
  value       = google_secret_manager_secret.secret.secret_id
}

output "secret_name" {
  description = "Secret resource name"
  value       = google_secret_manager_secret.secret.id
}

output "version" {
  description = "Secret version"
  value       = google_secret_manager_secret_version.version.name
}

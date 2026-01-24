output "zone_name" {
  description = "Name of the DNS zone"
  value       = google_dns_managed_zone.zone.name
}

output "dns_name" {
  description = "DNS name of the zone"
  value       = google_dns_managed_zone.zone.dns_name
}

output "name_servers" {
  description = "Name servers for the zone (public zones only)"
  value       = google_dns_managed_zone.zone.name_servers
}

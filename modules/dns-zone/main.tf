resource "google_dns_managed_zone" "zone" {
  name        = var.name
  dns_name    = var.dns_name
  project     = var.project_id
  description = var.description
  visibility  = var.visibility

  dynamic "private_visibility_config" {
    for_each = var.visibility == "private" ? [1] : []
    content {
      dynamic "networks" {
        for_each = var.private_visibility_networks
        content {
          network_url = networks.value
        }
      }
    }
  }
}

resource "google_dns_record_set" "records" {
  for_each = var.records

  name         = "${each.key}.${var.dns_name}"
  managed_zone = google_dns_managed_zone.zone.name
  project      = var.project_id
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
}

resource "google_compute_address" "psc_endpoint" {
  project      = var.project_id
  name         = var.name
  region       = var.region
  subnetwork   = var.subnetwork
  address_type = "INTERNAL"
  address      = var.ip_address
}

resource "google_compute_forwarding_rule" "psc_endpoint" {
  project                 = var.project_id
  name                    = var.name
  region                  = var.region
  network                 = var.network
  ip_address              = google_compute_address.psc_endpoint.id
  load_balancing_scheme   = ""
  target                  = var.target_service_attachment
  allow_psc_global_access = var.allow_psc_global_access
}

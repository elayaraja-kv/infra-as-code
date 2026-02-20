resource "google_project_service" "networkconnectivity" {
  project            = var.project_id
  service            = "networkconnectivity.googleapis.com"
  disable_on_destroy = false
}

resource "google_network_connectivity_service_connection_policy" "policy" {
  for_each = var.policies

  project       = coalesce(each.value.network_project, var.project_id)
  name          = each.key
  location      = var.location
  service_class = var.service_class
  description   = each.value.description
  labels        = each.value.labels
  network       = "projects/${coalesce(each.value.network_project, var.project_id)}/global/networks/${each.value.network_name}"

  psc_config {
    subnetworks = [
      for subnet in each.value.subnet_names :
      "projects/${coalesce(each.value.network_project, var.project_id)}/regions/${var.location}/subnetworks/${subnet}"
    ]
    limit = each.value.limit
  }

  depends_on = [google_project_service.networkconnectivity]
}

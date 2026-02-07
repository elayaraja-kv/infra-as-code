resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.name
  display_name = var.display_name != null ? var.display_name : var.name
}

resource "google_project_iam_member" "roles" {
  for_each = toset(var.roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}

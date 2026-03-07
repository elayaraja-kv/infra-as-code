module "instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 15.0"

  project_id   = var.project_id
  region       = var.region
  name_prefix  = "${var.name}-"
  machine_type = var.machine_type

  source_image_family  = var.image_family
  source_image_project = var.image_project

  disk_size_gb = var.disk_size_gb
  disk_type    = "pd-balanced"

  subnetwork         = var.subnetwork
  subnetwork_project = var.project_id

  service_account = {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script = var.startup_script
  }

  labels = var.labels
  tags   = var.tags
}

module "compute_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 15.0"

  project_id        = var.project_id
  region            = var.region
  zone              = var.zone
  hostname          = var.name
  instance_template = module.instance_template.self_link

  # Empty access_config = no external IP, outbound via Cloud NAT
  access_config = []
}

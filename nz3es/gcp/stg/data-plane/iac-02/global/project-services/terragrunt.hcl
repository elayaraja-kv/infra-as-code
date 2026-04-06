include "root" {
  path   = find_in_parent_folders("root-gcp.hcl")
  expose = true
}

include "project_services" {
  path = "${get_repo_root()}/modules/gcp/project-services/terragrunt.hcl"
}

inputs = {
  project_id = include.root.locals.project

  activate_apis = [
    # Compute & networking
    "compute.googleapis.com",
    "networkconnectivity.googleapis.com",
    "dns.googleapis.com",
    "servicenetworking.googleapis.com",

    # Kubernetes
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "gkebackup.googleapis.com",

    # Databases
    "sqladmin.googleapis.com",    # Cloud SQL
    "memorystore.googleapis.com", # Memorystore for Valkey

    # Security & identity
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "secretmanager.googleapis.com",
    "privateca.googleapis.com",

    # Messaging
    "pubsub.googleapis.com",

    # Observability
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudtrace.googleapis.com",
    "cloudbuild.googleapis.com",
  ]
}

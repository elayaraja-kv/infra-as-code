terraform {
  source = "tfr:///terraform-google-modules/project-factory/google//modules/project_services?version=18.2.0"
}

# Default inputs — override from individual project-services terragrunt.hcl
inputs = {
  disable_services_on_destroy = false
  disable_dependent_services  = false
}

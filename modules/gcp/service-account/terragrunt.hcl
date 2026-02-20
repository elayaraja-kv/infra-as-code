terraform {
  source = "tfr:///terraform-google-modules/service-accounts/google?version=4.7.0"
}


# Default inputs — override from individual SA terragrunt.hcl
inputs = {
  project_roles = []
}

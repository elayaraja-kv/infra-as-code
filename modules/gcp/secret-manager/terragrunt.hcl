terraform {
  source = "tfr:///GoogleCloudPlatform/secret-manager/google//modules/simple-secret?version=0.9.0"
}

# Default inputs — override from individual secret terragrunt.hcl
inputs = {
  labels = {}
}

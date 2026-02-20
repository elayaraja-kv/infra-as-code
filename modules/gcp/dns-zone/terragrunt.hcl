terraform {
  source = "tfr:///terraform-google-modules/cloud-dns/google?version=7.1.0"
}

# Default inputs — override from individual DNS zone terragrunt.hcl
inputs = {
  type       = "private"
  recordsets = []
  private_visibility_config_networks = []
}

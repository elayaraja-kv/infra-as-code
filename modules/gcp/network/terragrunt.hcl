terraform {
  source = "tfr:///terraform-google-modules/network/google?version=15.2.0"
}

# Default inputs — override from individual network terragrunt.hcl
inputs = {
  auto_create_subnetworks = false
  subnets                 = []
  secondary_ranges        = {}
}

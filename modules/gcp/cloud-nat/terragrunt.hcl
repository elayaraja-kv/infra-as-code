terraform {
  source = "tfr:///terraform-google-modules/cloud-nat/google?version=5.3.0"
}

inputs = {
  create_router = true
}

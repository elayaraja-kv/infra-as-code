terraform {
  source = "tfr:///terraform-google-modules/kubernetes-engine/google//modules/private-cluster?version=43.0.0"
}

# Default inputs — override from individual GKE cluster terragrunt.hcl
inputs = {
  enable_private_nodes    = true
  enable_private_endpoint = false
  remove_default_node_pool = true
  initial_node_count       = 0
  release_channel          = "REGULAR"
  deletion_protection      = true
  datapath_provider        = "ADVANCED_DATAPATH"
}

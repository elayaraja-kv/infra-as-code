terraform {
  source = "tfr:///terraform-google-modules/memorystore/google//modules/valkey?version=16.0.0"
}

# Default inputs — override from individual memorystore terragrunt.hcl
inputs = {
  node_type      = "SHARED_CORE_NANO"
  shard_count    = 1
  replica_count  = 0
  engine_version = "VALKEY_8_0"
  engine_configs = {}
}

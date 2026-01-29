module "valkey" {
  source  = "terraform-google-modules/memorystore/google//modules/valkey"
  version = "~> 16.0"

  project_id                  = var.project_id
  instance_id                 = var.instance_id
  location                    = var.location
  network                     = var.network
  node_type                   = var.node_type
  shard_count                 = var.shard_count
  replica_count               = var.replica_count
  labels                      = var.labels
  engine_version              = var.engine_version
  deletion_protection_enabled = var.deletion_protection_enabled
  authorization_mode          = var.authorization_mode
  transit_encryption_mode     = var.transit_encryption_mode
  engine_configs              = var.engine_configs
  service_connection_policies = var.service_connection_policies
}

terraform {
  source = "tfr:///terraform-google-modules/sql-db/google//modules/postgresql?version=28.0.1"
}

# Default inputs — override from individual cloud-sql terragrunt.hcl
inputs = {
  database_version = "POSTGRES_16"

  # Storage — override per instance for production
  disk_size             = 10
  disk_type             = "PD_SSD"
  disk_autoresize       = true
  disk_autoresize_limit = 0

  # Availability — override to REGIONAL for production HA
  availability_type = "ZONAL"

  # Private IP only via PSC — no public IP, no VPC peering
  # Override psc_allowed_consumer_projects per instance
  ip_configuration = {
    ipv4_enabled                                  = false
    enable_private_path_for_google_cloud_services = true
    private_network               = null
    allocated_ip_range            = null
    authorized_networks           = []
    psc_enabled                   = true
    psc_allowed_consumer_projects = []
  }

  # Backups
  backup_configuration = {
    enabled                        = true
    start_time                     = "16:00" # 16:00 UTC = 04:00 NZST (off-peak)
    point_in_time_recovery_enabled = true
    transaction_log_retention_days = 7
    retained_backups               = 7
    retention_unit                 = "COUNT"
    backup_retention_settings      = []
  }

  # Maintenance window — Sunday 15:00 UTC = Monday 03:00 NZST
  maintenance_window_day          = 7
  maintenance_window_hour         = 15
  maintenance_window_update_track = "stable"

  # Default DB + user (set enable_default_user = false and manage via additional_users)
  enable_default_db   = true
  enable_default_user = false

  deletion_protection = true

  database_flags = []
  user_labels    = {}
}

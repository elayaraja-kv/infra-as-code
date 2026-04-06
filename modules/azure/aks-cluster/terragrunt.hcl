# AKS cluster module wrapper
# Upstream: https://registry.terraform.io/modules/Azure/aks/azurerm
# Pin to a specific version; verify latest at registry before upgrading.
# NOTE: v9.x does NOT support API Server VNet Integration (Option D) — that requires v10+.
#       Current config uses Option C: public endpoint + IP whitelist only.
#       To upgrade: check registry for breaking changes between v9 and v10+.
#
# Rule: only static literal values here (booleans, strings, numbers, empty maps).
# Do NOT put keys whose values the deployment unit overrides with dependency references
# inside nested structures (e.g. node_pools) — deep-merge evaluates in the wrong context.
terraform {
  source = "tfr:///Azure/aks/azurerm?version=9.1.0"
}

inputs = {
  # Option C: public endpoint + IP whitelist (api_server_authorized_ip_ranges in deployment unit).
  # Option D (VNet integration) requires module v10+ — api_server_vnet_integration_enabled not in v9.x.
  private_cluster_enabled = false

  # Networking — Azure CNI Overlay
  network_plugin             = "azure"
  network_plugin_mode        = "overlay"
  network_policy             = "azure"
  load_balancer_sku          = "standard"
  net_profile_outbound_type  = "userAssignedNATGateway"
  net_profile_dns_service_ip = "172.16.0.10"
  net_profile_service_cidr   = "172.16.0.0/16"
  net_profile_pod_cidr       = "172.17.0.0/16"

  # System node pool defaults — override size and count per cluster
  agents_pool_name          = "system"
  agents_vm_size            = "Standard_D2s_v3"
  os_disk_size_gb           = 128
  os_disk_type              = "Managed"
  enable_auto_scaling       = true
  agents_min_count          = 1
  agents_max_count          = 3
  agents_count              = null # must be null when enable_auto_scaling = true
  agents_availability_zones = ["1", "2", "3"]

  # Cluster-wide settings
  sku_tier               = "Standard"
  local_account_disabled = true

  # Azure AD RBAC — role_based_access_control_enabled must be true when rbac_aad = true
  role_based_access_control_enabled = true
  rbac_aad                          = true
  rbac_aad_managed                  = true

  # Identity
  identity_type = "UserAssigned"

  # Automatic upgrades (patch only)
  automatic_channel_upgrade = "patch"
  node_os_channel_upgrade   = "NodeImage"

  # Add-ons (required)
  oidc_issuer_enabled                = true
  workload_identity_enabled          = true
  key_vault_secrets_provider_enabled = true

  # Add-ons (optional)
  azure_policy_enabled = false
  oms_agent_enabled    = false # disable Container Insights; set log_analytics_workspace_id per cluster to enable

  # node_pools intentionally omitted — deployment unit sets this with dependency
  # references inside the map values, which breaks deep-merge evaluation context.
}

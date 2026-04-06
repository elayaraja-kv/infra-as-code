include "root" {
  path   = find_in_parent_folders("root-azure.hcl")
  expose = true
}

include "aks" {
  path = "${get_repo_root()}/modules/azure/aks-cluster/terragrunt.hcl"
}

locals {
  cluster_name = "aks-${basename(get_terragrunt_dir())}-${include.root.locals.region_short}"
  base_path    = "${get_repo_root()}/${include.root.locals.org}/azure/${include.root.locals.environment}/${include.root.locals.plane}/${include.root.locals.project}"
}

dependency "resource_group" {
  config_path = "${local.base_path}/australiaeast/resource-group/aks"
  mock_outputs = {
    name     = "mock-rg"
    location = "australiaeast"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "network" {
  config_path = "${local.base_path}/australiaeast/network"
  mock_outputs = {
    vnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
    vnet_subnets_name_id = {
      "snet-aks-nodes"     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/snet-aks-nodes"
      "snet-aks-apiserver" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/snet-aks-apiserver"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "identity" {
  config_path = "${local.base_path}/global/iam/managed-identities/aks-cluster"
  mock_outputs = {
    id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mock-identity"
    principal_id = "00000000-0000-0000-0000-000000000000"
    client_id    = "00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  # Required — resolved from dependencies
  resource_group_name = dependency.resource_group.outputs.name
  location            = dependency.resource_group.outputs.location
  cluster_name        = local.cluster_name
  # prefix is used by the upstream module to name internal resources (e.g. log analytics workspace).
  # Must be non-empty even when oms_agent_enabled = false — module has an unconditional precondition.
  prefix         = local.cluster_name
  vnet_subnet_id = dependency.network.outputs.vnet_subnets_name_id["snet-aks-nodes"]
  identity_ids   = [dependency.identity.outputs.id]

  # Option C — IP whitelist (space-separated CIDRs in env var)
  # Option D (VNet integration) requires module v10+; snet-aks-apiserver is reserved for future upgrade.
  api_server_authorized_ip_ranges = compact(split(" ", get_env("AKS_API_SERVER_AUTHORIZED_IPS", "")))

  # Control plane version — pin to a tested minor; patch upgrades via automatic_channel_upgrade
  kubernetes_version = "1.33"

  # System node pool overrides (wrapper defaults: D2s_v3, min=1, max=3)
  agents_vm_size   = "Standard_D4s_v3"
  agents_max_count = 5

  # RBAC
  rbac_aad_admin_group_object_ids = compact([get_env("AKS_ADMIN_GROUP_ID", "")])

  # Maintenance window — Sat-Sun 3:00-9:00 AM NZST (= 14:00-20:00 UTC Fri-Sat)
  maintenance_window = {
    allowed = [
      { day = "Saturday", hours = [14, 15, 16, 17, 18, 19] },
      { day = "Sunday", hours = [14, 15, 16, 17, 18, 19] },
    ]
    not_allowed = []
  }

  # Additional user node pools — node_pools intentionally NOT in wrapper (contains dependency refs)
  node_pools = {
    workload = {
      name                = "workload"
      vm_size             = "Standard_D4s_v3"
      os_disk_size_gb     = 128
      os_disk_type        = "Managed"
      enable_auto_scaling = true
      min_count           = 0
      max_count           = 10
      availability_zones  = ["1", "2", "3"]
      vnet_subnet_id      = dependency.network.outputs.vnet_subnets_name_id["snet-aks-nodes"]
      node_labels         = { "nz3es/pool" = "workload" }
      node_taints         = []
      tags                = include.root.locals.tags
    }

    spot = {
      name                = "spot"
      vm_size             = "Standard_D4s_v3"
      os_disk_size_gb     = 128
      os_disk_type        = "Managed"
      priority            = "Spot"
      eviction_policy     = "Delete"
      spot_max_price      = -1
      enable_auto_scaling = true
      min_count           = 0
      max_count           = 20
      availability_zones  = ["1", "2", "3"]
      vnet_subnet_id      = dependency.network.outputs.vnet_subnets_name_id["snet-aks-nodes"]
      node_labels = {
        "nz3es/pool"                            = "spot"
        "kubernetes.azure.com/scalesetpriority" = "spot"
      }
      node_taints = [
        "kubernetes.azure.com/scalesetpriority=spot:NoSchedule",
        "nz3es/dedicated=true:NoSchedule",
      ]
      tags = include.root.locals.tags
    }
  }

  tags = include.root.locals.tags
}

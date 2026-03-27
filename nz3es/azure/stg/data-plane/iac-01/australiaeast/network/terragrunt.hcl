include "root" {
  path   = find_in_parent_folders("root-azure.hcl")
  expose = true
}

include "network" {
  path = "${get_repo_root()}/modules/azure/network/terragrunt.hcl"
}

dependency "resource_group" {
  config_path = "${get_terragrunt_dir()}/../resource-group/network"
  mock_outputs = {
    name     = "mock-rg"
    location = "australiaeast"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  resource_group_name = dependency.resource_group.outputs.name
  vnet_location       = include.root.locals.region
  vnet_name           = "vnet-${include.root.locals.environment}-${include.root.locals.project}-${include.root.locals.region_short}"

  # CNI Overlay: only nodes consume VNet IPs (pods use virtual overlay CIDR).
  # /22 = 1,024 IPs across 4 x /24 blocks — current + 2 spare for future subnets.
  #   10.1.0.0/24 → snet-aks-nodes   (in use)
  #   10.1.1.0/27 → snet-private-ep  (in use)
  #   10.1.2.0/24 → spare            (future node pool or workload subnet)
  #   10.1.3.0/24 → spare            (future use)
  address_space = ["10.1.0.0/22"]

  # Subnets (CAF prefix: snet-):
  #   snet-aks-nodes      — AKS node pools (nodes only; pods use CNI Overlay virtual CIDR)
  #   snet-private-ep     — Private endpoints (Key Vault, ACR, etc.)
  #   snet-aks-apiserver  — API server VNet integration (/28 minimum, delegated, Option D)
  subnet_names    = ["snet-aks-nodes", "snet-private-ep", "snet-aks-apiserver"]
  subnet_prefixes = ["10.1.0.0/24", "10.1.1.0/27", "10.1.3.0/28"]

  # Only snet-aks-apiserver is delegated — required for API Server VNet Integration (Option D).
  # snet-aks-nodes must NOT be delegated; AKS rejects delegated node subnets (SubnetIsDelegated error).
  # The upstream Azure/vnet/azurerm module requires service_name explicitly inside the value
  # (delegation.key = block name, delegation.value.service_name = service delegation name).
  subnet_delegation = {
    "snet-aks-apiserver" = {
      "Microsoft.ContainerService/managedClusters" = {
        service_name    = "Microsoft.ContainerService/managedClusters"
        service_actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }

  # Enable service endpoints on snet-aks-nodes for Key Vault and Storage
  subnet_service_endpoints = {
    "snet-aks-nodes"  = ["Microsoft.KeyVault", "Microsoft.Storage"]
    "snet-private-ep" = ["Microsoft.KeyVault", "Microsoft.Storage", "Microsoft.ContainerRegistry"]
  }

  use_for_each = true

  tags = include.root.locals.tags
}

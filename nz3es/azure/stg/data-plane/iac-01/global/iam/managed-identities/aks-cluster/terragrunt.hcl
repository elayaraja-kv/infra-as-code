include "root" {
  path   = find_in_parent_folders("root-azure.hcl")
  expose = true
}

locals {
  identity_name = basename(get_terragrunt_dir()) # "aks-cluster"
}

dependency "resource_group" {
  config_path = "${get_repo_root()}/nz3es/azure/stg/data-plane/iac-01/australiaeast/resource-group/aks"
  mock_outputs = {
    name     = "mock-gbl-rg"
    location = "australiaeast"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "network" {
  config_path = "${get_repo_root()}/nz3es/azure/stg/data-plane/iac-01/australiaeast/network"
  mock_outputs = {
    vnet_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet"
    vnet_subnets_name_id = { "snet-aks-nodes" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/snet-aks-nodes" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "${get_repo_root()}//modules/azure/managed-identity"
}

inputs = {
  name                = "id-${local.identity_name}-${include.root.locals.environment}-${include.root.locals.project}-${lookup(include.root.locals.region_short_names, dependency.resource_group.outputs.location, dependency.resource_group.outputs.location)}"
  resource_group_name = dependency.resource_group.outputs.name
  location            = dependency.resource_group.outputs.location
  tags                = include.root.locals.tags

  role_assignments = [
    # AKS control plane needs Network Contributor on the node subnet to manage NICs/routes
    {
      scope                = dependency.network.outputs.vnet_subnets_name_id["snet-aks-nodes"]
      role_definition_name = "Network Contributor"
    },
    # Pull images from ACR without storing credentials
    # Replace with actual ACR resource ID
    # {
    #   scope                = "/subscriptions/${get_env("ARM_SUBSCRIPTION_ID")}/resourceGroups/.../providers/Microsoft.ContainerRegistry/registries/..."
    #   role_definition_name = "AcrPull"
    # },
  ]

  # No federated credentials needed for the cluster control plane identity.
  # Add federated_credentials for workload identities (e.g. external-dns, cert-manager).
  federated_credentials = []
}

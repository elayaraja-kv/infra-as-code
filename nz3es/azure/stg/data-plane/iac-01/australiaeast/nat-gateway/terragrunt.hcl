include "root" {
  path   = find_in_parent_folders("root-azure.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//modules/azure/nat-gateway"
}

dependency "resource_group" {
  config_path = "${get_terragrunt_dir()}/../resource-group/network"
  mock_outputs = {
    name     = "mock-rg"
    location = "australiaeast"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "network" {
  config_path = "${get_terragrunt_dir()}/../network"
  mock_outputs = {
    vnet_subnets_name_id = {
      "snet-aks-nodes" = "/subscriptions/mock/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/snet-aks-nodes"
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  resource_group_name = dependency.resource_group.outputs.name
  location            = dependency.resource_group.outputs.location

  # CAF naming: ng- prefix for gateway, pip- for public IP
  name           = "ng-${include.root.locals.environment}-${include.root.locals.project}-${include.root.locals.region_short}"
  public_ip_name = "pip-ng-${include.root.locals.environment}-${include.root.locals.project}-${include.root.locals.region_short}"

  # Attach NAT to node subnet — provides outbound internet for private nodes
  # (image pulls, Helm repo downloads, etc.)
  # vnet_subnets_name_id is the name→id map output; vnet_subnets is a plain list (index only).
  subnet_ids = [dependency.network.outputs.vnet_subnets_name_id["snet-aks-nodes"]]

  tags = include.root.locals.tags
}

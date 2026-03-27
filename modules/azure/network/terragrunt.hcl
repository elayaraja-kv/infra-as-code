# Azure VNet module wrapper
# Upstream: https://registry.terraform.io/modules/Azure/vnet/azurerm
# Pin to a specific version; verify latest at registry before upgrading.
terraform {
  source = "tfr:///Azure/vnet/azurerm?version=4.1.0"
}

# Default inputs — override from individual network terragrunt.hcl.
# Required inputs NOT set here (must be provided by the deployment unit):
#   resource_group_name, vnet_location, vnet_name, vnet_address_space,
#   subnet_names, subnet_prefixes
inputs = {
  # Tags merged with per-unit tags in deployment units.
  use_for_each = true

  tags = {}

  # Subnet service endpoints — commonly needed for AKS + Key Vault / Storage access.
  subnet_service_endpoints = {}

  # Subnet delegation — required for AKS node pool subnets.
  # The upstream module requires service_name explicitly inside the value object:
  #   subnet_delegation = {
  #     "<subnet-name>" = {
  #       "Microsoft.ContainerService/managedClusters" = {
  #         service_name    = "Microsoft.ContainerService/managedClusters"
  #         service_actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  #       }
  #     }
  #   }
  subnet_delegation = {}

  # NSG — created per subnet; allow SSH/HTTPS by default (further locked down per unit).
  nsg_ids = {}

  # Route tables — attach custom route tables per subnet (e.g. for egress via NVA/firewall).
  route_tables_ids = {}
}

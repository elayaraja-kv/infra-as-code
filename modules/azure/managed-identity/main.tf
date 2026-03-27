resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "this" {
  for_each = { for ra in var.role_assignments : "${ra.scope}|${ra.role_definition_name}" => ra }

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_federated_identity_credential" "this" {
  for_each = { for fc in var.federated_credentials : fc.name => fc }

  name                = each.value.name
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this.id
  issuer              = each.value.issuer
  subject             = each.value.subject
  audience            = each.value.audiences
}

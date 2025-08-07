resource "azurerm_recovery_services_vault" "postgres_backup_vault" {
  name                = "${random_pet.name_prefix.id}-vault"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  sku                 = "Standard"
}

resource "azurerm_backup_policy_postgresql" "postgres_backup_policy" {
  name                = "${random_pet.name_prefix.id}-pgpolicy"
  resource_group_name = azurerm_resource_group.default.name
  recovery_vault_name = azurerm_recovery_services_vault.postgres_backup_vault.name
  backup_recurrence   = "Daily"
  retention_daily     = 7
}

output "resource_group_name" {
  value = azurerm_resource_group.default.name
}
output "postgresql_flexible_server_name" {
  value = azurerm_postgresql_flexible_server.default.name
}
output "postgresql_flexible_server_database_name" {
  value = azurerm_postgresql_flexible_server_database.default.name
}
output "postgresql_flexible_server_admin_password" {
  sensitive = true
  value     = azurerm_postgresql_flexible_server.default.administrator_password
}
output "recovery_services_vault_name" {
  value = azurerm_recovery_services_vault.postgres_backup_vault.name
}

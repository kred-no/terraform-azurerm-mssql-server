output "server" {
  sensitive = true
  value     = azurerm_mssql_server.MAIN
}

output "key_vault" {
  sensitive = true
  value     = azurerm_key_vault.MAIN
}

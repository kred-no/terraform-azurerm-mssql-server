output "server" {
  sensitive = false
  
  value = azurerm_mssql_server.MAIN
}

output "key_vault" {
  sensitive = false
  
  value = azurerm_key_vault.MAIN
}

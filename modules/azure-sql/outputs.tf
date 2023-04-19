////////////////////////
// Outputs
////////////////////////

output "server" {
  sensitive = true
  value     = azurerm_mssql_server.MAIN
}

output "databases" {
  sensitive = true

  value = [for db in azurerm_mssql_database.MAIN : db]
}

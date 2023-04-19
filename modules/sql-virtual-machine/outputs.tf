output "subnet" {
  sensitive = false
  value     = azurerm_subnet.MAIN
}

output "server" {
  sensitive = true
  value     = azurerm_mssql_virtual_machine.MAIN
}

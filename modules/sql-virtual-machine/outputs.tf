output "subnet" {
  sensitive = true
  value     = azurerm_subnet.MAIN
}

output "network_interface" {
  sensitive = true
  value     = azurerm_network_interface.MAIN
}

output "application_security_group" {
  sensitive = true
  value     = azurerm_application_security_group.MAIN
}

output "network_security_group" {
  sensitive = true
  value     = one(azurerm_network_security_group.MAIN[*])
}

output "sql_host" {
  sensitive = true
  value     = azurerm_windows_virtual_machine.MAIN
}

output "sql_server" {
  sensitive = true
  value     = azurerm_mssql_virtual_machine.MAIN
}

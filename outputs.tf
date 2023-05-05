output "virtual_machine" {
  sensitive = true
  value     = azurerm_windows_virtual_machine.MAIN
}

output "mssql_server" {
  sensitive = true
  value     = azurerm_mssql_virtual_machine.MAIN
}

output "application_security_group" {
  sensitive = false
  value     = azurerm_application_security_group.MAIN
}

output "network_interface" {
  sensitive = false
  value     = azurerm_network_interface.MAIN
}
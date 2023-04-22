output "subnet" {
  sensitive = false
  value     = one(module.SQL_VIRTUAL_MACHINE[*].subnet)
}

output "sql_server" {
  sensitive = true
  value     = one(module.SQL_VIRTUAL_MACHINE[*].sql_server)
}

output "sql_host" {
  sensitive = true
  value     = one(module.SQL_VIRTUAL_MACHINE[*].sql_host)
}

output "public_ip" {
  sensitive = true
  value     = one(module.LOAD_BALANCER[*].public_ip)
}

/*output "private_link_service" {
  sensitive = false
  value     = one(module.SQL_VIRTUAL_MACHINE[*].private_link_service)
}*/

output "key_vault" {
  sensitive = true
  value     = azurerm_key_vault.MAIN
}

output "storage_account" {
  sensitive = true
  value     = azurerm_storage_account.MAIN
}

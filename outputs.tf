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

output "key_vault" {
  sensitive = true
  value     = one(azurerm_key_vault.MAIN[*])
}

output "storage_account" {
  sensitive = true
  value     = one(azurerm_storage_account.MAIN[*])
}

output "sql_public_endpoint" {
  sensitive = true
  value     = one(module.SQL_VIRTUAL_MACHINE_PUBLIC_ENDPOINT[*].public_ip.fqdn)
}

/*output "private_link_service" {
  sensitive = false
  value     = one(module.SQL_VIRTUAL_MACHINE[*].private_link_service)
}*/
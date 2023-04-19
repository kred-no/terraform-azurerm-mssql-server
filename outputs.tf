/*output "key_vault" {
  sensitive = true
  value     = azurerm_key_vault.MAIN
}
*/

output "subnet" {
  sensitive = false
  value     = one(module.SQL_VIRTUAL_MACHINE[*].subnet)
}

output "server" {
  value = try(
    one(module.SQL_VIRTUAL_MACHINE[*].server),
    #one(module.AZURE_SQL[*].server),
    #one(module.AZURE_SQL_MANAGED[*].server),
    "",
  )
}

output "private_link_service" {
  sensitive = false
  value     = one(azurerm_private_link_service.SQL_PRIVATE_LINK[*])
}

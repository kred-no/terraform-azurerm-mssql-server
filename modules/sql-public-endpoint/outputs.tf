output "public_ip" {
  sensitive = true
  value = one(azurerm_public_ip.MAIN[*])
}

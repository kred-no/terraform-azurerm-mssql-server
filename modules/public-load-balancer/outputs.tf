output "public_ip" {
  sensitive = true
  value     = data.azurerm_public_ip.MAIN
}

output "load_balancer" {
  sensitive = true
  value     = azurerm_lb.MAIN
}

output "backend_pool" {
  sensitive = true
  value     = azurerm_lb_backend_address_pool.MAIN
}

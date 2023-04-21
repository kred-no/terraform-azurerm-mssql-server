////////////////////////
// Public IP
////////////////////////

resource "azurerm_public_ip_prefix" "MAIN" {
  name                = format("%s-ip-prefix", local.prefix)
  sku                 = local.sku
  prefix_length       = local.prefix_length
  tags                = var.tags
  location            = var.vnet.location
  resource_group_name = var.vnet.resource_group_name
}

resource "azurerm_public_ip" "MAIN" {
  name                = format("%s-public-ip", local.prefix)
  sku                 = local.sku
  allocation_method   = local.allocation_method
  domain_name_label   = var.domain_name_label
  public_ip_prefix_id = azurerm_public_ip_prefix.MAIN.id
  tags                = var.tags
  resource_group_name = var.vnet.resource_group_name
  location            = var.vnet.location

  lifecycle {
    create_before_destroy = true
  }
}

////////////////////////
// Load Balancer
////////////////////////

data "azurerm_public_ip" "MAIN" {
  name                = azurerm_public_ip.MAIN.name
  resource_group_name = azurerm_public_ip.MAIN.resource_group_name
}

resource "azurerm_lb" "MAIN" {
  name = format("%s-loadbalancer", local.prefix)
  sku  = local.sku

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = data.azurerm_public_ip.MAIN.id
  }

  tags                = var.tags
  location            = var.vnet.location
  resource_group_name = var.vnet.resource_group_name
}

resource "azurerm_lb_backend_address_pool" "MAIN" {
  name            = format("%s-backend-pool", local.prefix)
  loadbalancer_id = azurerm_lb.MAIN.id
}

/*resource "azurerm_lb_outbound_rule" "MAIN" {
  name                     = "AllowInternetAccess"
  protocol                 = "Tcp"
  allocated_outbound_ports = 1024

  frontend_ip_configuration {
    name = azurerm_lb.MAIN.frontend_ip_configuration.0.name
  }

  loadbalancer_id         = azurerm_lb.MAIN.id
  backend_address_pool_id = azurerm_lb_backend_address_pool.MAIN.id
}*/

////////////////////////
// NAT Pool Rules (Inbound)
////////////////////////

resource "azurerm_network_interface_backend_address_pool_association" "MAIN" {
  backend_address_pool_id = azurerm_lb_backend_address_pool.MAIN.id
  network_interface_id    = var.nic.id
  ip_configuration_name   = var.nic.ip_configuration.0.name
}

resource "azurerm_lb_nat_rule" "POOL" {
  for_each = {
    for rule in var.nat_pool_rules : rule.name => rule
  }

  name                = each.value["name"]
  protocol            = each.value["protocol"]
  frontend_port_start = each.value["frontend_port_start"]
  frontend_port_end   = each.value["frontend_port_end"]
  backend_port        = each.value["backend_port"]

  frontend_ip_configuration_name = azurerm_lb.MAIN.frontend_ip_configuration.0.name
  backend_address_pool_id        = azurerm_lb_backend_address_pool.MAIN.id
  loadbalancer_id                = azurerm_lb.MAIN.id
  resource_group_name            = var.vnet.resource_group_name
}

////////////////////////
// NAT Pool Rules (Inbound)
////////////////////////

resource "azurerm_lb_nat_rule" "NIC" {
  for_each = {
    for rule in var.nat_rules : rule.name => rule
  }

  name          = each.value["name"]
  protocol      = each.value["protocol"]
  frontend_port = each.value["frontend_port"]
  backend_port  = each.value["backend_port"]

  frontend_ip_configuration_name = azurerm_lb.MAIN.frontend_ip_configuration.0.name
  loadbalancer_id                = azurerm_lb.MAIN.id
  resource_group_name            = var.vnet.resource_group_name
}

resource "azurerm_network_interface_nat_rule_association" "MAIN" {
  for_each = {
    for rule in var.nat_rules : rule.name => rule
  }
  
  network_interface_id  = var.nic.id
  ip_configuration_name = var.nic.ip_configuration.0.name
  nat_rule_id           = azurerm_lb_nat_rule.NIC[each.key].id
}

////////////////////////
// Load Balancing Rules (Inbound)
////////////////////////

resource "azurerm_lb_probe" "MAIN" {
  for_each = {
    for rule in var.lb_rules : rule.name => rule
    if rule.probe_enabled
  }

  name                = each.value["name"]
  protocol            = each.value["probe_protocol"]
  port                = each.value["probe_port"]
  interval_in_seconds = each.value["interval_in_seconds"]
  number_of_probes    = each.value["number_of_probes"]
  probe_threshold     = each.value["probe_threshold"]

  loadbalancer_id = azurerm_lb.MAIN.id
}

resource "azurerm_lb_rule" "MAIN" {
  for_each = {
    for rule in var.lb_rules : rule.name => rule
  }

  name                  = each.value["name"]
  protocol              = each.value["protocol"]
  frontend_port         = each.value["frontend_port"]
  backend_port          = each.value["backend_port"]
  disable_outbound_snat = each.value["disable_outbound_snat"]
  probe_id              = each.value["probe_enabled"] ? azurerm_lb_probe.MAIN[each.key].id : null

  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.MAIN.id,
  ]

  frontend_ip_configuration_name = azurerm_lb.MAIN.frontend_ip_configuration.0.name
  loadbalancer_id                = azurerm_lb.MAIN.id
}

////////////////////////
// Private Link Service
////////////////////////

resource "azurerm_private_link_service" "MAIN" {
  count = 0

  name = format("%s-private-link", local.prefix)

  nat_ip_configuration {
    primary   = true
    name      = "primary"
    subnet_id = var.subnet.id
  }

  nat_ip_configuration {
    primary   = false
    name      = "secondary"
    subnet_id = var.subnet.id
  }

  load_balancer_frontend_ip_configuration_ids = [
    azurerm_lb.MAIN.frontend_ip_configuration.0.id
  ]

  location            = var.vnet.location
  resource_group_name = var.vnet.resource_group_name
}

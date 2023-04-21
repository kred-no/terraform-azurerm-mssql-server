////////////////////////
// Info
////////////////////////

// https://learn.microsoft.com/en-gb/azure/private-link/create-private-link-service-powershell
// https://learn.microsoft.com/en-gb/azure/private-link/private-link-service-overview
// https://youtu.be/4v-9zGHxVeI

////////////////////////
// Private Link Service
////////////////////////

resource "azurerm_public_ip" "MAIN" {
  count = 1

  name                = local.name
  sku                 = var.sku
  allocation_method   = "Static"
  domain_name_label   = var.domain_name_label
  tags                = var.tags
  resource_group_name = var.virtual_network.resource_group_name
  location            = var.virtual_network.location

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_lb" "MAIN" {
  count = 1

  name = local.name
  sku  = var.sku

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = one(azurerm_public_ip.MAIN[*].id)
  }

  tags                = var.tags
  location            = var.virtual_network.location
  resource_group_name = var.virtual_network.resource_group_name
}

resource "azurerm_lb_backend_address_pool" "MAIN" {
  count = 1

  name            = local.name
  loadbalancer_id = one(azurerm_lb.MAIN[*].id)
}

resource "azurerm_network_interface_backend_address_pool_association" "MAIN" {
  count = 1

  backend_address_pool_id = one(azurerm_lb_backend_address_pool.MAIN[*].id)
  network_interface_id    = var.network_interface.id
  ip_configuration_name   = var.network_interface.ip_configuration.0.name
}

resource "azurerm_lb_probe" "MAIN" {
  count = 1

  name                = "tcp-1433-sql"
  protocol            = "Tcp"
  port                = 1433
  interval_in_seconds = 30
  number_of_probes    = 2
  probe_threshold     = 1
  loadbalancer_id     = one(azurerm_lb.MAIN[*].id)
}

resource "azurerm_lb_rule" "MAIN" {
  count = 1

  name                           = local.name
  protocol                       = "Tcp"
  frontend_port                  = 1433
  backend_port                   = var.sql_connectivity_port
  frontend_ip_configuration_name = one(azurerm_lb.MAIN[*].frontend_ip_configuration.0.name)
  disable_outbound_snat          = local.disable_outbound_snat

  backend_address_pool_ids = [
    one(azurerm_lb_backend_address_pool.MAIN[*].id),
  ]

  probe_id        = one(azurerm_lb_probe.MAIN[*].id)
  loadbalancer_id = one(azurerm_lb.MAIN[*].id)
}

resource "azurerm_network_security_rule" "MAIN" {
  count = 1

  name      = "AllowSqlPrivateLinkService"
  priority  = 999
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_port_range      = "*"
  source_address_prefix  = "*"
  destination_port_range = "1433"

  destination_application_security_group_ids = [
    var.application_security_group.id
  ]

  network_security_group_name = var.network_security_group.name
  resource_group_name         = var.virtual_network.resource_group_name
}

resource "azurerm_private_link_service" "MAIN" {
  count = 1

  name = local.name

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
    one(azurerm_lb.MAIN[*].frontend_ip_configuration.0.id),
  ]

  location            = var.virtual_network.location
  resource_group_name = var.virtual_network.resource_group_name
}

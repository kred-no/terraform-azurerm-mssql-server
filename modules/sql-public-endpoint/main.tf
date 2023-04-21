////////////////////////
// Public SQL Access
////////////////////////

resource "azurerm_public_ip" "MAIN" {
  count = 1

  name                = "sql-public-endpoint"
  allocation_method   = "Static"
  sku                 = var.sku
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

  name = "sql-public-endpoint"
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

  name            = "sql-public-endpoint"
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

  name                = format("tcp-%s-sql", "1433")
  protocol            = "Tcp"
  port                = 1433
  interval_in_seconds = 30
  number_of_probes    = 2
  probe_threshold     = 1
  loadbalancer_id     = one(azurerm_lb.MAIN[*].id)
}

resource "azurerm_lb_rule" "MAIN" {
  count = 1

  name                           = "sql-public"
  protocol                       = "Tcp"
  frontend_port                  = 1433
  backend_port                   = 1433
  frontend_ip_configuration_name = one(azurerm_lb.MAIN[*].frontend_ip_configuration.0.name)
  disable_outbound_snat          = false

  backend_address_pool_ids = [
    one(azurerm_lb_backend_address_pool.MAIN[*].id),
  ]

  probe_id        = one(azurerm_lb_probe.MAIN[*].id)
  loadbalancer_id = one(azurerm_lb.MAIN[*].id)
}

resource "azurerm_network_security_rule" "MAIN" {
  count = 1

  name      = "AllowSqlPublicEndpoint"
  priority  = 1000
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_port_range      = "*"
  source_address_prefix  = "*"
  destination_port_range = "1433"

  destination_application_security_group_ids = [
    var.application_security_group.id,
  ]

  network_security_group_name = var.network_security_group.name
  resource_group_name         = var.virtual_network.resource_group_name
}

/*resource "azurerm_lb_outbound_rule" "MAIN" {
  count = 1

  name                     = "AllowInternetAccess"
  protocol                 = "Tcp"
  allocated_outbound_ports = 1024

  frontend_ip_configuration {
    name = join("-", [var.server_name, "feip"])
  }

  loadbalancer_id         = one(azurerm_lb.SQL_PUBLIC[*].id)
  backend_address_pool_id = one(azurerm_lb_backend_address_pool.SQL_PUBLIC[*].id)
}*/
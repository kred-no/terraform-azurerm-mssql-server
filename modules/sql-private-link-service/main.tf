////////////////////////
// Info
////////////////////////

// https://learn.microsoft.com/en-gb/azure/private-link/create-private-link-service-powershell
// https://learn.microsoft.com/en-gb/azure/private-link/private-link-service-overview
// https://youtu.be/4v-9zGHxVeI

////////////////////////
// Private Link Service
////////////////////////

resource "azurerm_public_ip" "SQL_PRIVATE_LINK" {
  count = 1

  name                = join("-", [var.server_name, "sql-plink"])
  sku                 = var.sql_public_access_sku
  allocation_method   = "Static"
  domain_name_label   = join("", [var.server_name, "plink"])
  tags                = var.tags
  resource_group_name = var.virtual_network.resource_group_name
  location            = var.virtual_network.location

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_lb" "SQL_PRIVATE_LINK" {
  count = 1

  name = join("-", [var.server_name, "plink"])
  sku  = var.sql_public_access_sku

  frontend_ip_configuration {
    name                 = join("-", [var.server_name, "feip"])
    public_ip_address_id = one(azurerm_public_ip.SQL_PRIVATE_LINK[*].id)
  }

  tags                = var.tags
  location            = var.virtual_network.location
  resource_group_name = var.virtual_network.resource_group_name
}

resource "azurerm_lb_backend_address_pool" "SQL_PRIVATE_LINK" {
  count = 1

  name            = join("-", [var.server_name, "bepool"])
  loadbalancer_id = one(azurerm_lb.SQL_PRIVATE_LINK[*].id)
}

resource "azurerm_network_interface_backend_address_pool_association" "SQL_PRIVATE_LINK" {
  count = 1

  backend_address_pool_id = one(azurerm_lb_backend_address_pool.SQL_PRIVATE_LINK[*].id)
  network_interface_id    = azurerm_network_interface.MAIN.id
  ip_configuration_name   = azurerm_network_interface.MAIN.ip_configuration.0.name
}

resource "azurerm_lb_probe" "SQL_PRIVATE_LINK" {
  count = 1

  name                = format("tcp-%s-sql", var.sql_connectivity_port)
  protocol            = "Tcp"
  port                = var.sql_connectivity_port
  interval_in_seconds = 30
  number_of_probes    = 2
  probe_threshold     = 1
  loadbalancer_id     = one(azurerm_lb.SQL_PRIVATE_LINK[*].id)
}

resource "azurerm_lb_rule" "SQL_PRIVATE_LINK" {
  count = 1

  name                           = "sql-private-link"
  protocol                       = "Tcp"
  frontend_port                  = 1433
  backend_port                   = var.sql_connectivity_port
  frontend_ip_configuration_name = join("-", [var.server_name, "feip"])
  #disable_outbound_snat          = true
  disable_outbound_snat = false

  backend_address_pool_ids = [
    one(azurerm_lb_backend_address_pool.SQL_PRIVATE_LINK[*].id),
  ]

  probe_id        = one(azurerm_lb_probe.SQL_PRIVATE_LINK[*].id)
  loadbalancer_id = one(azurerm_lb.SQL_PRIVATE_LINK[*].id)
}

resource "azurerm_network_security_rule" "SQL_PRIVATE_LINK" {
  count = 1

  name      = "AllowSqlPrivateLink"
  priority  = 999
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_port_range      = "*"
  source_address_prefix  = "*"
  destination_port_range = "1433"

  destination_application_security_group_ids = [
    one(azurerm_application_security_group.MAIN[*].id),
  ]

  network_security_group_name = one(azurerm_network_security_group.MAIN[*].name)
  resource_group_name         = var.virtual_network.resource_group_name
}

resource "azurerm_private_link_service" "SQL_PRIVATE_LINK" {
  count = 1

  name = join("-", [var.server_name, "service"])

  nat_ip_configuration {
    primary   = true
    name      = "primary"
    subnet_id = azurerm_subnet.MAIN.id
  }

  nat_ip_configuration {
    primary   = false
    name      = "secondary"
    subnet_id = azurerm_subnet.MAIN.id
  }

  load_balancer_frontend_ip_configuration_ids = [
    one(azurerm_lb.SQL_PRIVATE_LINK[*].frontend_ip_configuration.0.id),
  ]

  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
}

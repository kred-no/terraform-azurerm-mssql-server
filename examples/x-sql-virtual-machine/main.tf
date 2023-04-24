// Creates a virtual machine running Microsoft SQL Server
//
// Options:
//   - Default: Access SQL Server & Rdp via NAT. Blocs
//   - Option: Access SQL server host using Azure Bastion Host
//   - Option: Create an Azure Private Link Service for the Load Balancer & access resources via Private Link.

////////////////////////
// Test Config
////////////////////////

locals {

  flag = {
    bastion_enabled = false
    lb_enabled      = true
  }

  // Core Resources
  rg_prefix              = "sqlvm"
  rg_location            = "westeurope"
  vnet_name              = "SQL-EXAMPLE-VNET"
  vnet_address_space     = ["192.168.168.0/24"]
  subnet_address_prefix  = cidrsubnet("192.168.168.0/24", 2, 0)
  bastion_address_prefix = cidrsubnet("192.168.168.0/24", 2, 1)
  bastion_sku            = "Basic"

  // Module Config
  vm_size            = "Standard_D2ds_v4" # Standard_B4ms
  vm_priority        = "Spot"
  vm_eviction_policy = "Delete"
  vm_max_bid_price   = "-1"
  
  vm_source_image = {
    offer     = "sql2022-ws2022"
    publisher = "MicrosoftSQLServer"
    sku       = "sqldev-gen2"
  }

  // Network Security
  nat_rules = [{
    name          = "tcp-1433-mssql"
    protocol      = "Tcp"
    frontend_port = 1433
    backend_port  = 1433
    }, {
    name          = "tcp-3389-rdp"
    protocol      = "Tcp"
    frontend_port = 3389
    backend_port  = 3389
  }]

  nsg_rules = [{
    name                   = "AllowSqlInbound"
    priority               = 2000
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_address_prefix  = "Internet"
    source_port_range      = "*"
    destination_port_range = "1433"
    }, {
    name                   = "DenyRdpInbound"
    priority               = 1999
    direction              = "Inbound"
    access                 = "Deny"
    protocol               = "Tcp"
    source_address_prefix  = "Internet"
    source_port_range      = "*"
    destination_port_range = "3389"
  }]

  lb_rules = []
}

////////////////////////
// Outputs
////////////////////////
// N/A

////////////////////////
// Core Resources
////////////////////////

resource "random_string" "RESOURCE_GROUP" {
  length  = 6
  special = false

  keepers = {
    prefix = local.rg_prefix
  }
}

resource "azurerm_resource_group" "MAIN" {
  name     = join("-", [random_string.RESOURCE_GROUP.keepers.prefix, random_string.RESOURCE_GROUP.result])
  location = local.rg_location
}

resource "azurerm_virtual_network" "MAIN" {
  name          = local.vnet_name
  address_space = local.vnet_address_space

  resource_group_name = azurerm_resource_group.MAIN.name
  location            = azurerm_resource_group.MAIN.location
}

resource "azurerm_subnet" "MAIN" {
  name = "SqlSubnet"

  address_prefixes = [local.subnet_address_prefix]

  service_endpoints = [
    "Microsoft.KeyVault",
    "Microsoft.Storage",
  ]

  virtual_network_name = azurerm_virtual_network.MAIN.name
  resource_group_name  = azurerm_virtual_network.MAIN.resource_group_name
}

////////////////////////
// Module
////////////////////////

module "SQL_SERVER" {
  source = "../../../terraform-azurerm-mssql-server"

  depends_on = [azurerm_subnet.MAIN]

  // Module Config
  vm_size                   = local.vm_size
  vm_priority               = local.vm_priority
  vm_eviction_policy        = local.vm_eviction_policy
  vm_max_bid_price          = local.vm_max_bid_price
  vm_source_image_reference = local.vm_source_image

  // Resource References
  subnet         = azurerm_subnet.MAIN
  resource_group = azurerm_resource_group.MAIN
}

////////////////////////
// Azure Bastion
////////////////////////

resource "azurerm_subnet" "BASTION" {
  count      = local.flag.bastion_enabled ? 1 : 0
  depends_on = [module.SQL_SERVER] // Create AFTER module

  name                 = "AzureBastionSubnet"
  address_prefixes     = [local.bastion_address_prefix]
  resource_group_name  = azurerm_virtual_network.MAIN.resource_group_name
  virtual_network_name = azurerm_virtual_network.MAIN.name
}

resource "azurerm_public_ip" "BASTION" {
  count      = local.flag.bastion_enabled ? 1 : 0
  depends_on = [module.SQL_SERVER] // Create AFTER module

  name                = join("-", [azurerm_resource_group.MAIN.name, "bastion-pip"])
  allocation_method   = "Static"
  sku                 = "Standard"
  location            = azurerm_virtual_network.MAIN.location
  resource_group_name = azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_bastion_host" "MAIN" {
  count = local.flag.bastion_enabled ? 1 : 0

  name              = join("-", [azurerm_resource_group.MAIN.name, "bastion"])
  sku               = local.bastion_sku
  tunneling_enabled = local.bastion_sku != "Standard" ? false : true

  ip_configuration {
    name                 = "bastion-ipcfg"
    subnet_id            = one(azurerm_subnet.BASTION[*].id)
    public_ip_address_id = one(azurerm_public_ip.BASTION[*].id)
  }

  location            = azurerm_virtual_network.MAIN.location
  resource_group_name = azurerm_virtual_network.MAIN.resource_group_name
}

////////////////////////
// Network Security Group
////////////////////////

resource "azurerm_network_security_group" "MAIN" {
  count = local.flag.lb_enabled ? 1 : 0

  name = join("-", [azurerm_subnet.MAIN.name, "nsg"])
  
  location            = azurerm_virtual_network.MAIN.location
  resource_group_name = azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "MAIN" {
  count = local.flag.lb_enabled ? 1 : 0

  subnet_id                 = azurerm_subnet.MAIN.id
  network_security_group_id = one(azurerm_network_security_group.MAIN[*].id)
}

resource "azurerm_network_security_rule" "MAIN" {
  for_each = {
    for rule in local.nsg_rules : join("-", [rule.direction, rule.priority]) => rule
    if local.flag.lb_enabled
  }

  name      = each.value["name"]
  priority  = each.value["priority"]
  direction = each.value["direction"]
  access    = each.value["access"]
  protocol  = each.value["protocol"]

  source_port_range     = each.value["source_port_range"]
  source_address_prefix = try(each.value["source_address_prefix"], null)

  source_application_security_group_ids = flatten([
    anytrue([
      each.value["direction"] != "Outbound",
    ]) ? [] : [one(module.SQL_SERVER[*].application_security_group.id)]
  ])

  destination_port_range     = each.value["destination_port_range"]
  destination_address_prefix = try(each.value["destination_address_prefix"], null)

  destination_application_security_group_ids = flatten([
    anytrue([
      each.value["direction"] != "Inbound",
    ]) ? [] : [one(module.SQL_SERVER[*].application_security_group.id)]
  ])

  network_security_group_name = one(azurerm_network_security_group.MAIN[*].name)
  resource_group_name         = azurerm_virtual_network.MAIN.resource_group_name
}

////////////////////////
// Load Balancer
////////////////////////

resource "azurerm_public_ip" "MAIN" {
  count = local.flag.lb_enabled ? 1 : 0

  name                = join("-", [module.SQL_SERVER.virtual_machine.name, "pip"])
  sku                 = "Standard"
  allocation_method   = "Static"
  #domain_name_label   = var.domain_name_label

  resource_group_name = azurerm_resource_group.MAIN.name
  location            = azurerm_resource_group.MAIN.location

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_lb" "MAIN" {
  count = local.flag.lb_enabled ? 1 : 0
  
  name = join("-", [module.SQL_SERVER.virtual_machine.name, "lb"])
  sku  = "Standard"

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = one(azurerm_public_ip.MAIN[*].id)
  }

  location            = azurerm_virtual_network.MAIN.location
  resource_group_name = azurerm_virtual_network.MAIN.resource_group_name
}

////////////////////////
// Load Balancer | NAT Rules
////////////////////////

resource "azurerm_lb_nat_rule" "MAIN" {
  for_each = {
    for rule in local.nat_rules : rule.name => rule
    if local.flag.lb_enabled
  }

  name          = each.value["name"]
  protocol      = each.value["protocol"]
  frontend_port = each.value["frontend_port"]
  backend_port  = each.value["backend_port"]

  frontend_ip_configuration_name = one(azurerm_lb.MAIN[*].frontend_ip_configuration.0.name)
  loadbalancer_id                = one(azurerm_lb.MAIN[*].id)
  resource_group_name            = azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_network_interface_nat_rule_association" "MAIN" {
  for_each = {
    for rule in local.nat_rules : rule.name => rule
    if local.flag.lb_enabled
  }

  network_interface_id  = module.SQL_SERVER.network_interface.id
  ip_configuration_name = module.SQL_SERVER.network_interface.ip_configuration.0.name
  nat_rule_id           = azurerm_lb_nat_rule.MAIN[each.key].id
}

////////////////////////
// Load Balancer | Rules
////////////////////////

resource "azurerm_lb_backend_address_pool" "MAIN" {
  count = local.flag.lb_enabled ? 1 : 0

  name            = join("-", [module.SQL_SERVER.virtual_machine.name, "pool"])
  loadbalancer_id = one(azurerm_lb.MAIN[*].id)
}

resource "azurerm_network_interface_backend_address_pool_association" "MAIN" {
  count = local.flag.lb_enabled ? 1 : 0

  backend_address_pool_id = one(azurerm_lb_backend_address_pool.MAIN[*].id)
  network_interface_id    = module.SQL_SERVER.network_interface.id
  ip_configuration_name   = module.SQL_SERVER.network_interface.ip_configuration.0.name
}

resource "azurerm_lb_probe" "MAIN" {
  for_each = {
    for rule in local.lb_rules : rule.name => rule
    if alltrue([
      rule.probe_enabled,
      local.flag.lb_enabled,
    ])
  }

  name                = each.value["name"]
  protocol            = each.value["probe_protocol"]
  port                = each.value["probe_port"]
  interval_in_seconds = each.value["interval_in_seconds"]
  number_of_probes    = each.value["number_of_probes"]
  probe_threshold     = each.value["probe_threshold"]

  loadbalancer_id = one(azurerm_lb.MAIN[*].id)
}

resource "azurerm_lb_rule" "MAIN" {
  for_each = {
    for rule in local.lb_rules : rule.name => rule
    if local.flag.lb_enabled
  }

  name                  = each.value["name"]
  protocol              = each.value["protocol"]
  frontend_port         = each.value["frontend_port"]
  backend_port          = each.value["backend_port"]
  disable_outbound_snat = each.value["disable_outbound_snat"]
  probe_id              = each.value["probe_enabled"] ? azurerm_lb_probe.MAIN[each.key].id : null

  backend_address_pool_ids = [
    one(azurerm_lb_backend_address_pool.MAIN[*].id),
  ]

  frontend_ip_configuration_name = one(azurerm_lb.MAIN[*].frontend_ip_configuration.0.name)
  loadbalancer_id                = one(azurerm_lb.MAIN[*].id)
}

////////////////////////
// Load Balancer | Private Link Service
////////////////////////

/*resource "azurerm_private_link_service" "MAIN" {
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
*/
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
    bastion_enabled          = false
    private_link_enabled     = false
    private_endpoint_enabled = false
  }

  // Test Resources
  rg_prefix   = "TFSQLVM"
  rg_location = "westeurope"

  vnet_name          = "SQL-EXAMPLE-VNET"
  vnet_address_space = ["192.168.168.0/24"]

  private_endpoint_address_prefix = cidrsubnet("192.168.168.0/24", 2, 2)
  bastion_address_prefix          = cidrsubnet("192.168.168.0/24", 2, 1)
  bastion_sku                     = "Basic"

  // Module Config
  sql_type = "virtual-machine"

  subnet = {
    vnet_index = 0
    newbits    = 2
    netnum     = 0
    
    service_endpoints = [
      "Microsoft.KeyVault",
      "Microsoft.Storage",
    ]
  }

  nat_rules = [{
    name          = "tcp-1433-mssql"
    frontend_port = 1433
    backend_port  = 1433
  }, {
    name          = "tcp-3389-rdp"
    frontend_port = 3389
    backend_port  = 3389
  }]

  nsg_rules = [{
    name                   = "AllowSqlInbound"
    priority               = 500
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    source_address_prefix  = "1433"
    destination_port_range = "1433"
  }, {
    name                   = "AllowRdpInbound"
    priority               = 499
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "3389"
    source_address_prefix  = "*"
    destination_port_range = "3389"
  }]

  source_image = {
    offer     = "sql2022-ws2022"
    publisher = "MicrosoftSQLServer"
    sku       = "sqldev-gen2"
  }
}

////////////////////////
// Outputs
////////////////////////

output "storage_account" {
  sensitive = true
  value     = module.SQL_SERVER.storage_account
}

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
  name                = local.vnet_name
  address_space       = local.vnet_address_space
  resource_group_name = azurerm_resource_group.MAIN.name
  location            = azurerm_resource_group.MAIN.location
}

////////////////////////
// Module | SQL Virtual Machine
////////////////////////

module "SQL_SERVER" {
  source = "../../../terraform-azurerm-mssql-server"

  depends_on = [
    azurerm_resource_group.MAIN,
    azurerm_virtual_network.MAIN,
  ]

  // Module Config
  sql_type                  = local.sql_type
  subnet                    = local.subnet
  vm_source_image_reference = local.source_image
  nat_rules                 = local.nat_rules
  nsg_rules                 = local.nsg_rules
  private_link_enabled      = local.flag.private_link_enabled

  // Resource References
  resource_group  = azurerm_resource_group.MAIN
  virtual_network = azurerm_virtual_network.MAIN
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
// Example | Private Endpoint
////////////////////////

/*
resource "azurerm_subnet" "PRIVATE_ENDPOINT" {
  count      = local.flag.private_endpoint_enabled ? 1 : 0
  depends_on = [module.SQL_SERVER] // Create AFTER module

  name             = "PrivateEndpointSubnet"
  address_prefixes = [local.private_endpoint_address_prefix]

  service_endpoints                         = []
  private_endpoint_network_policies_enabled = false

  resource_group_name  = azurerm_virtual_network.MAIN.resource_group_name
  virtual_network_name = azurerm_virtual_network.MAIN.name
}

resource "azurerm_private_endpoint" "PRIVATE_ENDPOINT" {
  count = local.flag.private_endpoint_enabled ? 1 : 0

  name      = "sql-private-endpoint"
  subnet_id = one(azurerm_subnet.PRIVATE_ENDPOINT[*].id)

  private_service_connection {
    name                           = "sql-privateservice-connection"
    private_connection_resource_id = module.SQL_SERVER.private_link_service.id
    is_manual_connection           = false
  }

  location            = azurerm_virtual_network.MAIN.location
  resource_group_name = azurerm_virtual_network.MAIN.resource_group_name
}*/
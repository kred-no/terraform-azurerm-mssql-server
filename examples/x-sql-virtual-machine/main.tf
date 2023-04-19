////////////////////////
// Config
////////////////////////

locals {
  rg_prefix   = "tf-sqlsrv"
  rg_location = "northeurope"

  vnet_name          = "sql-example-vnet"
  vnet_address_space = ["192.168.168.0/24"]
  
  connectivity_type = "PRIVATE"

  bastion_enabled = true
}

////////////////////////
// Core Resources
////////////////////////

resource "random_id" "X" {
  byte_length = 3

  keepers = {
    prefix = local.rg_prefix
  }
}

resource "azurerm_resource_group" "MAIN" {
  name     = join("-", [random_id.X.keepers.prefix, random_id.X.hex])
  location = local.rg_location
}

resource "azurerm_virtual_network" "MAIN" {
  name                = local.vnet_name
  address_space       = local.vnet_address_space
  resource_group_name = azurerm_resource_group.MAIN.name
  location            = azurerm_resource_group.MAIN.location
}

////////////////////////
// SQL Virtual Machine
////////////////////////

module "SQL_SERVER" {
  source = "../../../terraform-azurerm-mssql-server"

  depends_on = [
    azurerm_resource_group.MAIN,
    azurerm_virtual_network.MAIN,
  ]

  // Module Config
  deployment_type       = "virtual-machine"
  sql_connectivity_type = local.connectivity_type

  #server_priority        = "Spot"
  #server_eviction_policy = "Delete"

  subnet_newbits = 2
  subnet_netnum  = 0

  // Resource References
  resource_group  = azurerm_resource_group.MAIN
  virtual_network = azurerm_virtual_network.MAIN
}

resource "azurerm_mssql_database" "DEMO" {
  count = 0
  
  name           = "demo-db"
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb    = 4
  sku_name       = "S0"
  server_id      = module.SQL_SERVER.server.id
}

////////////////////////
// Azure Bastion
////////////////////////

resource "azurerm_subnet" "BASTION" {
  depends_on = [module.SQL_SERVER]
  count      = local.bastion_enabled ? 1 : 0

  name = "AzureBastionSubnet"

  address_prefixes = [cidrsubnet(
    element(azurerm_virtual_network.MAIN.address_space, 0), // VNet index
    2,                                                      // Add network bits
    1,                                                      // Network number
  )]

  resource_group_name  = azurerm_virtual_network.MAIN.resource_group_name
  virtual_network_name = azurerm_virtual_network.MAIN.name
}

resource "azurerm_public_ip" "BASTION" {
  depends_on = [module.SQL_SERVER]
  count      = local.bastion_enabled ? 1 : 0

  name                = "sql-pip"
  allocation_method   = "Static"
  sku                 = "Standard"
  location            = azurerm_virtual_network.MAIN.location
  resource_group_name = azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_bastion_host" "MAIN" {
  depends_on = [module.SQL_SERVER] // Create AFTER module
  count      = local.bastion_enabled ? 1 : 0

  name = "sql-bastion"
  sku  = "Basic"

  ip_configuration {
    name                 = "bastion-ipcfg"
    subnet_id            = one(azurerm_subnet.BASTION[*].id)
    public_ip_address_id = one(azurerm_public_ip.BASTION[*].id)
  }

  location            = azurerm_virtual_network.MAIN.location
  resource_group_name = azurerm_virtual_network.MAIN.resource_group_name
}

output "bastion_host" {
  sensitive = false
  value     = one(azurerm_bastion_host.MAIN[*].dns_name)
}

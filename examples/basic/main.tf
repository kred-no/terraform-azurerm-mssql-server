//////////////////////////////////
// Customization
//////////////////////////////////

locals {
  rg_prefix          = "mssql-server"
  rg_location        = "northeurope"
  vnet_name          = "example-mssql-virtual-network"
  vnet_address_space = ["192.168.168.0/24"]
}

resource "random_id" "X" {
  keepers = {
    prefix = local.rg_prefix
  }

  byte_length = 3
}

//////////////////////////////////
// Required Resources
//////////////////////////////////

resource "azurerm_resource_group" "MAIN" {
  name     = join("-", [random_id.X.keepers.prefix, random_id.X.hex])
  location = local.rg_location
}

resource "azurerm_virtual_network" "MAIN" {
  name          = local.vnet_name
  address_space = local.vnet_address_space
  
  resource_group_name = azurerm_resource_group.MAIN.name
  location            = azurerm_resource_group.MAIN.location
}

//////////////////////////////////
// Module
//////////////////////////////////

module "BASIC_MSSQL_SERVER" {
  source = "../../../terraform-azurerm-mssql-server"
  
  // Module Overrides
  // N/A

  // External Resource References
  resource_group  = azurerm_resource_group.MAIN
  virtual_network = azurerm_virtual_network.MAIN
}

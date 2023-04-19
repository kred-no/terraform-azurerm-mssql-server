//////////////////////////////////
// Config
//////////////////////////////////

locals {
  rg_prefix   = "tf-sqlsrv"
  rg_location = "northeurope"

  databases = [{
    name     = "elastic-db1"
    sku_name = "ElasticPool"
    #license_type                = "LicenseIncluded"
    auto_pause_delay_in_minutes = 60
  }]
}

//////////////////////////////////
// Resources
//////////////////////////////////

resource "random_id" "X" {
  keepers = {
    prefix = local.rg_prefix
  }

  byte_length = 3
}

resource "azurerm_resource_group" "MAIN" {
  name     = join("-", [random_id.X.keepers.prefix, random_id.X.hex])
  location = local.rg_location
}

//////////////////////////////////
// Module
//////////////////////////////////

/*module "BASIC_MSSQL_SERVER" {
  source = "../../../terraform-azurerm-mssql-server"

  // Module Config
  server_name          = join("-", ["sqlsrv", random_id.X.hex])
  elastic_pool_enabled = true
  databases            = local.databases

  firewall_rules = var.firewall_rules

  // Resource References
  resource_group = azurerm_resource_group.MAIN
}*/

//////////////////////////////////
// Module | Outputs
//////////////////////////////////

output "server_fqdn" {
  sensitive = true
  value     = module.BASIC_MSSQL_SERVER.server.fully_qualified_domain_name
}

output "databases" {
  sensitive = true
  value     = module.BASIC_MSSQL_SERVER.databases
}

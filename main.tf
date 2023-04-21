////////////////////////
// Flags
////////////////////////

locals {
  flags = {
    testing_enabled = false
  }
}

////////////////////////
// Sources
////////////////////////

data "azurerm_client_config" "CURRENT" {}

data "azurerm_resource_group" "MAIN" {
  count = anytrue([
    var.deployment_type == "virtual-machine",
  ]) ? 1 : 0

  name = var.resource_group.name
}

data "azurerm_virtual_network" "MAIN" {
  count = anytrue([
    var.deployment_type == "virtual-machine",
  ]) ? 1 : 0

  name                = var.virtual_network.name
  resource_group_name = var.virtual_network.resource_group_name
}

////////////////////////
// Azure Key Vault
////////////////////////

// Globally Unique
// Must be between 3 and 24 characters in length
// May only contain 0-9, a-z, A-Z, and not consecutive -.

resource "random_string" "KEY_VAULT" {
  length  = 22 // prefixed with 'kv'
  special = false

  keepers = {
    prefix              = "kv"
    resource_group_name = one(data.azurerm_resource_group.MAIN[*].name)
  }
}

resource "azurerm_key_vault" "MAIN" {
  count = 1

  name                        = join("-", [random_string.KEY_VAULT.keepers.prefix, random_string.KEY_VAULT.result])
  sku_name                    = "standard"
  enabled_for_disk_encryption = true
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  tenant_id           = data.azurerm_client_config.CURRENT.tenant_id
  location            = one(data.azurerm_resource_group.MAIN[*].location)
  resource_group_name = one(data.azurerm_resource_group.MAIN[*].name)
}

resource "azurerm_key_vault_access_policy" "CLIENT" {
  count = 0

  key_vault_id = one(azurerm_key_vault.MAIN[*].id)
  tenant_id    = data.azurerm_client_config.CURRENT.tenant_id
  object_id    = data.azurerm_client_config.CURRENT.object_id

  key_permissions    = ["Get"]
  secret_permissions = ["Get"]
}

////////////////////////
// Azure Storage Account
////////////////////////

// Globally Unique
// Must be between 3 and 24 characters in length
// May only contain numbers and lowercase letters

resource "random_string" "STORAGE_ACCOUNT" {
  length  = 20 // prefixed with 'sacc'
  special = false
  upper   = false

  keepers = {
    prefix              = "sacc"
    resource_group_name = one(data.azurerm_resource_group.MAIN[*].name)
  }
}

resource "azurerm_storage_account" "MAIN" {
  count = 1

  name                     = join("", [random_string.STORAGE_ACCOUNT.keepers.prefix, random_string.STORAGE_ACCOUNT.result])
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
  resource_group_name      = one(data.azurerm_resource_group.MAIN[*].name)
  location                 = one(data.azurerm_resource_group.MAIN[*].location)
}

resource "azurerm_storage_container" "SQL_DATABASE_BACKUPS" {
  count = alltrue([
    local.flags.testing_enabled,
  ]) ? 1 : 0

  name                  = "sql-database-backups"
  container_access_type = "blob"
  storage_account_name  = one(azurerm_storage_account.MAIN[*].name)
}

////////////////////////
// SQL Virtual Machine
////////////////////////

module "SQL_VIRTUAL_MACHINE" {
  count  = var.deployment_type != "virtual-machine" ? 0 : 1
  source = "./modules/sql-virtual-machine"

  subnet_name        = var.subnet_name
  subnet_vnet_index  = var.subnet_vnet_index
  subnet_newbits     = var.subnet_newbits
  subnet_netnum      = var.subnet_netnum
  subnet_nsg_enabled = var.subnet_nsg_enabled
  subnet_nsg_rules   = var.subnet_nsg_rules

  server_name                   = var.server_name
  server_size                   = var.server_size
  server_priority               = var.server_priority
  server_eviction_policy        = var.server_eviction_policy
  server_max_bid_price          = var.server_max_bid_price
  server_timezone               = var.server_timezone
  server_source_image_reference = var.server_source_image_reference
  server_os_disk                = var.server_os_disk
  server_admin_username         = var.server_admin_username
  server_admin_password         = var.server_admin_password

  sql_license_type          = var.sql_license_type
  sql_r_services_enabled    = var.sql_r_services_enabled
  sql_connectivity_port     = var.sql_connectivity_port
  sql_connectivity_type     = var.sql_connectivity_type
  sql_auto_backup           = var.sql_auto_backup
  sql_auto_patching         = var.sql_auto_patching
  sql_instance              = var.sql_instance
  sql_key_vault_credential  = var.sql_key_vault_credential
  sql_assessment            = var.sql_assessment
  sql_storage_configuration = var.sql_storage_configuration
  sql_update_username       = var.sql_update_username
  sql_update_password       = var.sql_update_password

  // References
  tags = var.tags

  resource_group  = one(data.azurerm_resource_group.MAIN[*])
  virtual_network = one(data.azurerm_virtual_network.MAIN[*])
}

module "SQL_VIRTUAL_MACHINE_PUBLIC_ENDPOINT" {
  source = "./modules/sql-public-endpoint"

  count = alltrue([
    var.deployment_type == "virtual-machine",
    var.sql_public_access_enabled,
  ]) ? 1 : 0
  
  // Config
  sku = var.sql_public_access_sku

  // References
  tags                        = var.tags
  domain_name_label          = one(module.SQL_VIRTUAL_MACHINE[*].sql_host.name)
  network_interface          = one(module.SQL_VIRTUAL_MACHINE[*].network_interface)
  application_security_group = one(module.SQL_VIRTUAL_MACHINE[*].application_security_group)
  network_security_group     = one(module.SQL_VIRTUAL_MACHINE[*].network_security_group)
  virtual_network            = one(data.azurerm_virtual_network.MAIN[*])
}

////////////////////////
// Azure SQL
////////////////////////
// N/A

////////////////////////
// Azure SQL Managed Instance
////////////////////////
// N/A

////////////////////////
// Sources
////////////////////////

data "azurerm_client_config" "CURRENT" {}

data "azuread_service_principal" "AZURE_KEY_VAULT" {
  display_name = "Azure Key Vault"
}

data "azurerm_resource_group" "MAIN" {
  name = var.resource_group.name
}

data "azurerm_virtual_network" "MAIN" {
  name                = var.virtual_network.name
  resource_group_name = var.virtual_network.resource_group_name
}

data "azurerm_public_ip_prefix" "MAIN" {
  count = length(var.public_ip_prefix[*]) > 0 ? 1 : 0
  
  name                = var.public_ip_prefix.name
  resource_group_name = var.public_ip_prefix.resource_group_name
}

data "azurerm_nat_gateway" "MAIN" {
  count = length(var.nat_gateway[*]) > 0 ? 1 : 0
  
  name                = var.nat_gateway.name
  resource_group_name = var.nat_gateway.resource_group_name
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
    resource_group_name = data.azurerm_resource_group.MAIN.name
  }
}

resource "azurerm_storage_account" "MAIN" {
  name                     = join("", [random_string.STORAGE_ACCOUNT.keepers.prefix, random_string.STORAGE_ACCOUNT.result])
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
  resource_group_name      = data.azurerm_resource_group.MAIN.name
  location                 = data.azurerm_resource_group.MAIN.location
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
    resource_group_name = data.azurerm_resource_group.MAIN.name
  }
}

resource "azurerm_role_assignment" "MAIN" {
  role_definition_name = "Storage Account Key Operator Service Role"
  principal_id         = data.azuread_service_principal.AZURE_KEY_VAULT.id // Allows "Azure Key Vault service" to manage this Storage Account
  scope                = azurerm_storage_account.MAIN.id
}

resource "azurerm_key_vault" "MAIN" {
  depends_on = [azurerm_role_assignment.MAIN]

  name                        = join("", [random_string.KEY_VAULT.keepers.prefix, random_string.KEY_VAULT.result])
  sku_name                    = "standard"
  enabled_for_disk_encryption = true
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  tenant_id           = data.azurerm_client_config.CURRENT.tenant_id
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

resource "azurerm_key_vault_access_policy" "CLIENT" {
  key_vault_id = azurerm_key_vault.MAIN.id
  
  tenant_id    = data.azurerm_client_config.CURRENT.tenant_id
  object_id    = data.azurerm_client_config.CURRENT.object_id

  certificate_permissions = ["Create", "List", "Get", "Delete", "Purge"]
  key_permissions         = ["Create", "List", "Get", "Delete", "Purge", "GetRotationPolicy", "SetRotationPolicy", "Rotate"]
  secret_permissions      = ["List", "Get", "Set", "Delete", "Purge"]
  storage_permissions     = ["Update", "List", "Get", "Set", "Delete", "Purge", "ListSAS", "GetSAS", "DeleteSAS"]
}

////////////////////////
// Storage Account Access Key Rotation
////////////////////////

resource "azurerm_key_vault_managed_storage_account" "MAIN" {
  depends_on = [azurerm_key_vault_access_policy.CLIENT]

  name                         = join("", [random_string.STORAGE_ACCOUNT.keepers.prefix, random_string.STORAGE_ACCOUNT.result])
  storage_account_key          = "key1"
  regenerate_key_automatically = true
  regeneration_period          = "P1D"
  key_vault_id                 = azurerm_key_vault.MAIN.id
  storage_account_id           = azurerm_storage_account.MAIN.id
}

////////////////////////
// SQL Virtual Machine
////////////////////////

module "SQL_VIRTUAL_MACHINE" {
  source = "./modules/sql-virtual-machine"
  count  = var.sql_type != "virtual-machine" ? 0 : 1

  subnet    = var.subnet
  nsg_rules = var.nsg_rules

  vm_name                      = var.vm_name
  vm_size                      = var.vm_size
  vm_priority                  = var.vm_priority
  vm_eviction_policy           = var.vm_eviction_policy
  vm_max_bid_price             = var.vm_max_bid_price
  vm_timezone                  = var.vm_timezone
  vm_source_image_reference    = var.vm_source_image_reference
  vm_os_disk                   = var.vm_os_disk
  vm_admin_username            = var.vm_admin_username
  vm_admin_password            = var.vm_admin_password
  vm_extension_aad_login       = var.vm_extension_aad_login
  vm_extension_bginfo          = var.vm_extension_bginfo
  vm_extension_compute_scripts = var.vm_extension_compute_scripts
  vm_extension_azure_scripts   = var.vm_extension_azure_scripts

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
  tags            = var.tags
  key_vault       = azurerm_key_vault.MAIN
  storage_account = azurerm_storage_account.MAIN
  resource_group  = data.azurerm_resource_group.MAIN
  virtual_network = data.azurerm_virtual_network.MAIN
  nat_gateway     = one(data.azurerm_nat_gateway.MAIN[*])
}

////////////////////////
// Load Balancer
////////////////////////

module "LOAD_BALANCER" {
  source = "./modules/load-balancer"

  // Only create LoadBalancer if it is required
  count = anytrue([
    var.private_link_enabled,
    length(var.nat_rules) > 0,
    length(var.nat_pool_rules) > 0,
    length(var.lb_rules) > 0,
  ]) ? 1 : 0

  depends_on = [module.SQL_VIRTUAL_MACHINE]

  domain_name_label = var.vm_name // Globally Unique. E.g. <label>.<location>.cloudapp.azure.com
  nat_rules         = var.nat_rules
  nat_pool_rules    = var.nat_pool_rules
  lb_rules          = var.lb_rules

  // References
  tags       = var.tags
  vnet       = data.azurerm_virtual_network.MAIN
  pip_prefix = one(data.azurerm_public_ip_prefix.MAIN[*])

  subnet = one(module.SQL_VIRTUAL_MACHINE[*].subnet)
  nic    = one(module.SQL_VIRTUAL_MACHINE[*].network_interface)
  asg    = one(module.SQL_VIRTUAL_MACHINE[*].application_security_group)
  nsg    = one(module.SQL_VIRTUAL_MACHINE[*].network_security_group)
}

////////////////////////
// Azure SQL
////////////////////////
// N/A

////////////////////////
// Azure SQL Managed Instance
////////////////////////
// N/A


data "azurerm_client_config" "CURRENT" {}

locals {
  flags = {
    create_resources        = true
    create_key_vault        = true
    create_key_vault_policy = true
    outputs_disabled        = false
  }

  resource_group_prefix   = "resource-group"
  resource_group_location = "northeurope"
}

resource "random_string" "RESOURCE_GROUP" {
  count = local.flags.create_resources ? 1 : 0

  length  = 12
  special = false

  keepers = {
    prefix = local.resource_group_prefix
  }
}

resource "azurerm_resource_group" "MAIN" {
  count = alltrue([
    local.flags.create_resources,
  ]) ? 1 : 0

  name     = join("-", [one(random_string.RESOURCE_GROUP[*].keepers.prefix), one(random_string.RESOURCE_GROUP[*].id)])
  location = local.resource_group_location
}

output "resource_group" {
  value = alltrue([
    local.flags.outputs_disabled,
  ]) ? null : one(azurerm_resource_group.MAIN[*])
}

////////////////////////
// Key Vault
////////////////////////

// Globally Unique
// Must be between 3 and 24 characters in length
// May only contain 0-9, a-z, A-Z, and not consecutive -.

resource "random_string" "KEY_VAULT" {
  count = alltrue([
    local.flags.create_resources,
    local.flags.create_key_vault,
  ]) ? 1 : 0

  length  = 22
  special = false

  keepers = {
    prefix = "kv"
  }
}

resource "azurerm_key_vault" "MAIN" {
  count = alltrue([
    local.flags.create_resources,
    local.flags.create_key_vault,
  ]) ? 1 : 0

  name                        = join("", [one(random_string.KEY_VAULT[*].keepers.prefix), one(random_string.KEY_VAULT[*].id)])
  sku_name                    = "standard"
  enabled_for_disk_encryption = true
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  tenant_id           = data.azurerm_client_config.CURRENT.tenant_id
  location            = one(azurerm_resource_group.MAIN[*].location)
  resource_group_name = one(azurerm_resource_group.MAIN[*].name)
}


resource "azurerm_key_vault_access_policy" "EXAMPLE" {
  count = alltrue([
    local.flags.create_resources,
    local.flags.create_key_vault,
    local.flags.create_key_vault_policy,
  ]) ? 1 : 0

  key_vault_id = one(azurerm_key_vault.MAIN[*].id)
  tenant_id    = data.azurerm_client_config.CURRENT.tenant_id
  object_id    = data.azurerm_client_config.CURRENT.object_id

  key_permissions    = ["Get"]
  secret_permissions = ["Get"]
}

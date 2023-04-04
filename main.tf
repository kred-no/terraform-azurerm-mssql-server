////////////////////////
// External Resources
////////////////////////

data "azurerm_client_config" "CURRENT" {}

data "azurerm_resource_group" "MAIN" {
  name = var.resource_group.name
}

////////////////////////
// Randomizer
////////////////////////

resource "random_id" "X" {
  byte_length = 4
}

////////////////////////
// Key Vault
////////////////////////

resource "azurerm_key_vault" "MAIN" {
  name                        = join("", [var.prefix, random_id.X.hex])
  sku_name                    = var.key_vault_sku_name
  soft_delete_retention_days  = 7
  enabled_for_disk_encryption = true
  purge_protection_enabled    = false

  access_policy {
    tenant_id = data.azurerm_client_config.CURRENT.tenant_id
    object_id = data.azurerm_client_config.CURRENT.object_id

    key_permissions     = ["Get"]
    secret_permissions  = ["Get", "Backup", "Delete", "List", "Purge", "Recover", "Restore", "Set"]
    storage_permissions = ["Get"]
  }

  tenant_id           = data.azurerm_client_config.CURRENT.tenant_id
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

////////////////////////
// Storage Account
////////////////////////

resource "azurerm_storage_account" "MAIN" {
  name                     = join("", [var.prefix, random_id.X.hex])
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type

  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}

////////////////////////
// SQL Server
////////////////////////

resource "random_password" "SQLSERVER" {
  length  = 16
  special = true
}

resource "azurerm_key_vault_secret" "SQLSERVER" {
  name         = join("-", [var.mssql_server_name,"AdminPassword"])
  value        = random_password.SQLSERVER.result
  key_vault_id = azurerm_key_vault.MAIN.id
}

resource "azurerm_mssql_server" "MAIN" {
  name                         = var.mssql_server_name
  version                      = var.mssql_server_version
  minimum_tls_version          = var.mssql_server_minimum_tls_version
  administrator_login          = var.mssql_server_administrator_username
  administrator_login_password = azurerm_key_vault_secret.SQLSERVER.value

  identity {
    type = "SystemAssigned"
  }

  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}

////////////////////////
// SQL Server Auditing
////////////////////////

resource "azurerm_storage_container" "AUDIT" {
  name                  = join("-", [azurerm_mssql_server.MAIN.name, "audit"])
  container_access_type = "private"
  storage_account_name  = azurerm_storage_account.MAIN.name
}


resource "azurerm_mssql_server_extended_auditing_policy" "MAIN" {
  server_id                               = azurerm_mssql_server.MAIN.id
  log_monitoring_enabled                  = false
  storage_account_access_key_is_secondary = false
  retention_in_days                       = var.auditing_retention_in_days
  storage_endpoint                        = azurerm_storage_container.AUDIT.id
  storage_account_access_key              = azurerm_storage_account.MAIN.primary_access_key

}

////////////////////////
// SQL Server Firewall Rules
////////////////////////

resource "azurerm_mssql_firewall_rule" "MAIN" {
  for_each = {
    for rule in var.firewall_rules: rule.name => rule
  }
  
  name             = each.value["name"]
  start_ip_address = each.value["start_ip_address"]
  end_ip_address   = each.value["namend_ip_address"]
  
  server_id        = azurerm_mssql_server.MAIN.id
}

////////////////////////
// SQL Databases
////////////////////////

resource "azurerm_mssql_database" "MAIN" {
  for_each = {
    for db in var.databases : db.name => db
  }

  name           = each.value["name"]
  sku_name       = each.value["sku_name"]
  collation      = each.value["collation"]
  license_type   = each.value["license_type"]
  max_size_gb    = each.value["max_size_gb"]
  read_scale     = each.value["read_scale"]
  zone_redundant = each.value["zone_redundant"]
  create_mode    = each.value["create_mode"]

  dynamic "import" {
    for_each = [
      each.value["bacpac_import"],
    ]
    
    content {
      storage_uri                  = import.value["storage_uri"]
      storage_key                  = import.value["storage_key"]
      storage_key_type             = import.value["storage_key_type"]
      administrator_login          = import.value["administrator_login"]
      administrator_login_password = import.value["administrator_login_password"]
      authentication_type          = import.value["authentication_type"]
      storage_account_id           = import.value["storage_account_id"]
    }
  }

  server_id = azurerm_mssql_server.MAIN.id
}

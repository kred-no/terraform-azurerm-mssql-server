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
// Azure Key Vault
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
// Azure Storage Account
////////////////////////

resource "azurerm_storage_account" "MAIN" {
  name                     = substr(join("", ["sa", random_id.X.hex, sha1(var.prefix)]), 0, 24)
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type

  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}

////////////////////////
// Azure SQL Server
////////////////////////

resource "random_password" "SQLSERVER" {
  length  = 16
  special = true
}

resource "azurerm_key_vault_secret" "SQLSERVER" {
  name         = join("-", [var.server_name, "AdminPassword"])
  value        = random_password.SQLSERVER.result
  key_vault_id = azurerm_key_vault.MAIN.id
}

resource "azurerm_mssql_server" "MAIN" {
  name                                 = var.server_name
  version                              = var.server_version
  minimum_tls_version                  = var.server_minimum_tls_version
  administrator_login                  = var.server_administrator_username
  administrator_login_password         = azurerm_key_vault_secret.SQLSERVER.value
  connection_policy                    = var.server_connection_policy
  public_network_access_enabled        = var.server_public_network_access_enabled
  outbound_network_restriction_enabled = var.server_outbound_network_restriction_enabled

  identity {
    type = "SystemAssigned"
  }

  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}

////////////////////////
// Azure SQL Server | Auditing
////////////////////////

resource "azurerm_storage_container" "AUDIT" {
  name                  = join("-", [azurerm_mssql_server.MAIN.name, "audit"])
  container_access_type = "private"
  storage_account_name  = azurerm_storage_account.MAIN.name
}

resource "azurerm_mssql_server_extended_auditing_policy" "MAIN" {
  count = 0

  server_id                               = azurerm_mssql_server.MAIN.id
  log_monitoring_enabled                  = false
  storage_account_access_key_is_secondary = false
  retention_in_days                       = var.auditing_retention_in_days
  storage_endpoint                        = azurerm_storage_container.AUDIT.id
  storage_account_access_key              = azurerm_storage_account.MAIN.primary_access_key

}

////////////////////////
// Azure SQL Server | Firewall Rules
////////////////////////

resource "azurerm_mssql_firewall_rule" "MAIN" {
  for_each = {
    for rule in var.firewall_rules : rule.name => rule
  }

  name             = each.value["name"]
  start_ip_address = each.value["start_ip_address"]
  end_ip_address   = each.value["namend_ip_address"]

  server_id = azurerm_mssql_server.MAIN.id
}

////////////////////////
// Azure SQL Server | Databases
////////////////////////

resource "azurerm_mssql_database" "MAIN" {
  for_each = {
    for db in var.databases : db.name => db
  }

  name                        = each.value["name"]
  sku_name                    = each.value["sku_name"]
  collation                   = each.value["collation"]
  license_type                = each.value["license_type"]
  max_size_gb                 = each.value["max_size_gb"]
  read_scale                  = each.value["read_scale"]
  zone_redundant              = each.value["zone_redundant"]
  create_mode                 = each.value["create_mode"]
  geo_backup_enabled          = each.value["geo_backup_enabled"]
  ledger_enabled              = each.value["ledger_enabled"]
  auto_pause_delay_in_minutes = each.value["auto_pause_delay_in_minutes"]

  dynamic "import" {
    for_each = each.value["import"][*]

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

  dynamic "short_term_retention_policy" {
    for_each = each.value["short_term_retention_policy"][*]

    content {
      retention_days           = short_term_retention_policy.value["short_term_retention_policy"]
      backup_interval_in_hours = short_term_retention_policy.value["backup_interval_in_hours"]
    }
  }

  dynamic "long_term_retention_policy" {
    for_each = each.value["long_term_retention_policy"][*]

    content {
      weekly_retention  = long_term_retention_policy.value["weekly_retention"]
      monthly_retention = long_term_retention_policy.value["monthly_retention"]
      yearly_retention  = long_term_retention_policy.value["yearly_retention"]
      week_of_year      = long_term_retention_policy.value["week_of_year"]
    }
  }

  dynamic "threat_detection_policy" {
    for_each = each.value["threat_detection_policy"][*]

    content {
      state                      = threat_detection_policy.value["state"]
      disabled_alerts            = threat_detection_policy.value["disabled_alerts"]
      email_account_admins       = threat_detection_policy.value["email_account_admins"]
      email_addresses            = threat_detection_policy.value["email_addresses"]
      retention_days             = threat_detection_policy.value["retention_days"]
      storage_account_access_key = threat_detection_policy.value["storage_account_access_key"]
      storage_endpoint           = threat_detection_policy.value["storage_endpoint"]
    }
  }

  server_id = azurerm_mssql_server.MAIN.id
}

////////////////////////
// Sources
////////////////////////

data "azurerm_resource_group" "MAIN" {
  name = var.resource_group.name
}

data "azurerm_virtual_network" "MAIN" {
  name                = var.azurerm_virtual_network.name
  resource_group_name = var.azurerm_virtual_network.resource_group_name
}

////////////////////////
// Azure SQL Server
////////////////////////

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
// Server Auditing
////////////////////////

resource "azurerm_storage_container" "AUDIT" {
  count = var.server_extended_auditing_policy_enabled ? 1 : 0

  name                  = join("-", [azurerm_mssql_server.MAIN.name, "audit"])
  container_access_type = "private"
  storage_account_name  = azurerm_storage_account.MAIN.name
}

resource "azurerm_mssql_server_extended_auditing_policy" "MAIN" {
  count = var.server_extended_auditing_policy_enabled ? 1 : 0

  server_id                               = azurerm_mssql_server.MAIN.id
  log_monitoring_enabled                  = false
  storage_account_access_key_is_secondary = false
  retention_in_days                       = var.auditing_retention_in_days
  storage_endpoint                        = one(azurerm_storage_container.AUDIT[*].id)
  storage_account_access_key              = azurerm_storage_account.MAIN.primary_access_key

}

////////////////////////
// Elastic Pool
////////////////////////

resource "azurerm_mssql_elasticpool" "MAIN" {
  count = var.elastic_pool_enabled ? 1 : 0

  name                           = join("-", [azurerm_mssql_server.MAIN.name, "epool"])
  license_type                   = var.elastic_pool_license_type
  max_size_gb                    = var.elastic_pool_max_size_gb
  maintenance_configuration_name = var.elastic_pool_maintenance_configuration_name

  dynamic "sku" {
    for_each = var.elastic_pool_sku[*]

    content {
      name     = sku.value["name"]
      capacity = sku.value["capacity"]
      tier     = sku.value["tier"]
      family   = sku.value["family"]
    }
  }

  dynamic "per_database_settings" {
    for_each = var.elastic_pool_per_database_settings[*]

    content {
      min_capacity = per_database_settings.value["min_capacity"]
      max_capacity = per_database_settings.value["max_capacity"]
    }
  }

  server_name         = azurerm_mssql_server.MAIN.name
  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}

////////////////////////
// Databases
////////////////////////

resource "azurerm_mssql_database" "MAIN" {
  for_each = {
    for db in var.databases : db.name => db
  }

  name                           = each.value["name"]
  sku_name                       = each.value["sku_name"]
  collation                      = each.value["collation"]
  license_type                   = each.value["license_type"]
  max_size_gb                    = each.value["max_size_gb"]
  read_scale                     = each.value["read_scale"]
  zone_redundant                 = each.value["zone_redundant"]
  create_mode                    = each.value["create_mode"]
  geo_backup_enabled             = each.value["geo_backup_enabled"]
  ledger_enabled                 = each.value["ledger_enabled"]
  auto_pause_delay_in_minutes    = each.value["auto_pause_delay_in_minutes"]
  maintenance_configuration_name = each.value["maintenance_configuration_name"]

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

  elastic_pool_id = var.elastic_pool_enabled ? one(azurerm_mssql_elasticpool.MAIN[*].id) : null
  server_id       = azurerm_mssql_server.MAIN.id
}

////////////////////////
// Firewall Rules
////////////////////////

resource "azurerm_mssql_firewall_rule" "MAIN" {
  for_each = {
    for rule in var.firewall_rules : rule.name => rule
  }

  name             = each.value["name"]
  start_ip_address = each.value["start_ip_address"]
  end_ip_address   = each.value["end_ip_address"]

  server_id = azurerm_mssql_server.MAIN.id
}

resource "azurerm_mssql_outbound_firewall_rule" "MAIN" {
  for_each = toset(var.outbound_firewall_rules)

  name      = each.value
  server_id = azurerm_mssql_server.MAIN.id
}

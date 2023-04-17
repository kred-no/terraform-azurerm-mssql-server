////////////////////////
// External Resources
////////////////////////

variable "resource_group" {
  type = object({
    name     = string
    location = string
  })
}

variable "tags" {
  type    = map(string)
  default = {}
}

////////////////////////
// Override | Key Vault
////////////////////////

variable "prefix" {
  type    = string
  default = "sql"
}

variable "key_vault_sku_name" {
  type    = string
  default = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku_name)
    error_message = "Valid values: standard, premium"
  }
}

////////////////////////
// Override | Storage Account
////////////////////////

variable "storage_account_tier" {
  type    = string
  default = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "Invalid value provided."
  }
}

variable "storage_account_replication_type" {
  type    = string
  default = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_account_replication_type)
    error_message = "Invalid value provided."
  }
}

////////////////////////
// Override | MSSQL Server
////////////////////////

variable "server_name" {
  type    = string
  default = "primary"
}

variable "server_version" {
  type    = string
  default = "12.0"

  validation {
    condition     = contains(["12.0", "2.0"], var.server_version)
    error_message = "Invalid value provided."
  }
}

variable "server_minimum_tls_version" {
  type    = string
  default = "1.2"

  validation {
    condition     = contains(["1.2", "1.1", "1.0", "Disabled"], var.server_minimum_tls_version)
    error_message = "Invalid value provided."
  }
}

variable "server_administrator_username" {
  type    = string
  default = "Magnum"
}

variable "server_connection_policy" {
  type    = string
  default = null
}

variable "server_public_network_access_enabled" {
  type    = bool
  default = null
}

variable "server_outbound_network_restriction_enabled" {
  type    = bool
  default = null
}

variable "auditing_retention_in_days" {
  type    = number
  default = 6
}

////////////////////////
// Override | Firewall Rules
////////////////////////

variable "firewall_rules" {
  type = list(object({
    name             = string
    start_ip_address = string
    end_ip_address   = string
  }))

  default = []
}

////////////////////////
// Override | MSSQL Databases
////////////////////////

variable "databases" {
  description = "Databases to create on server."

  type = list(object({
    name                           = string
    sku_name                       = optional(string, "Basic")
    license_type                   = optional(string, "LicenseIncluded")
    collation                      = optional(string)
    create_mode                    = optional(string)
    max_size_gb                    = optional(string)
    read_scale                     = optional(string)
    zone_redundant                 = optional(bool)
    auto_pause_delay_in_minutes    = optional(number)
    geo_backup_enabled             = optional(bool)
    ledger_enabled                 = optional(bool)
    creation_source_database_id    = optional(string)
    elastic_pool_id                = optional(string)
    maintenance_configuration_name = optional(string)

    threat_detection_policy = optional(object({
      state                      = string
      disabled_alerts            = list(string)
      email_account_admins       = string
      email_addresses            = list(string)
      retention_days             = number
      storage_account_access_key = string
      storage_endpoint           = string
    }), null)

    long_term_retention_policy = optional(object({
      weekly_retention  = string
      monthly_retention = string
      yearly_retention  = string
      week_of_year      = number
    }), null)

    short_term_retention_policy = optional(object({
      retention_days           = number
      backup_interval_in_hours = number
    }), null)

    import = optional(object({
      storage_uri                  = string
      storage_key                  = string
      storage_key_type             = string
      administrator_login          = string
      administrator_login_password = string
      authentication_type          = string
      storage_account_id           = string
    }), null)
  }))

  default = []

  validation {
    condition = alltrue(flatten([
      for db in var.databases : [
        contains(["GP_S_Gen5_2", "HS_Gen4_1", "BC_Gen5_2", "ElasticPool", "Basic", "S0", "P2", "DW100c", "DS100"], db.sku_name),
        contains(["LicenseIncluded", "BasePrice"], db.license_type),
        db.auto_pause_delay_in_minutes >= 60 && db.auto_pause_delay_in_minutes <= 10080,
      ]
    ]))

    error_message = "Invalid value(s) provided."
  }
}

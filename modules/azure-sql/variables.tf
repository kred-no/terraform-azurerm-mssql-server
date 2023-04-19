////////////////////////
// SQL Server
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

variable "server_extended_auditing_policy_enabled" {
  type    = bool
  default = false
}

////////////////////////
// Elastic Pool
////////////////////////

variable "elastic_pool_enabled" {
  type    = bool
  default = false
}

variable "elastic_pool_license_type" {
  type    = string
  default = null
}

variable "elastic_pool_max_size_gb" {
  type    = number
  default = 300
}

variable "elastic_pool_maintenance_configuration_name" {
  type    = string
  default = "SQL_Default"
}

variable "elastic_pool_sku" {
  type = object({
    name     = string
    tier     = string
    capacity = number
    family   = optional(string)
  })

  default = {
    name     = "StandardPool"
    tier     = "Standard"
    capacity = 50
  }
}

variable "elastic_pool_per_database_settings" {
  type = object({
    min_capacity = number
    max_capacity = number
  })

  default = {
    min_capacity = 0
    max_capacity = 50
  }
}

////////////////////////
// Databases
////////////////////////

variable "databases" {
  description = "Databases to create on server."

  type = list(object({
    name                           = string
    sku_name                       = string
    license_type                   = optional(string)
    collation                      = optional(string)
    create_mode                    = optional(string)
    max_size_gb                    = optional(string)
    read_scale                     = optional(string)
    zone_redundant                 = optional(bool)
    auto_pause_delay_in_minutes    = optional(number)
    geo_backup_enabled             = optional(bool)
    ledger_enabled                 = optional(bool)
    creation_source_database_id    = optional(string)
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
      ]
    ]))

    error_message = "Invalid value(s) provided."
  }
}

////////////////////////
// Firewall Rules
////////////////////////

variable "firewall_rules" {
  type = list(object({
    name             = string
    start_ip_address = string
    end_ip_address   = string
  }))

  default = []
}

variable "outbound_firewall_rules" {
  type    = list(string)
  default = []
}

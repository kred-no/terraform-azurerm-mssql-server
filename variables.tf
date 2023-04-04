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
  type   = string
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

variable "mssql_server_name" {
  type    = string
  default = "primary"
}

variable "mssql_server_version" {
  type    = string
  default = "12.0"

  validation {
    condition     = contains(["12.0", "2.0"], var.mssql_server_version)
    error_message = "Invalid value provided."
  }
}

variable "mssql_server_minimum_tls_version" {
  type    = string
  default = "1.2"

  validation {
    condition     = contains(["1.2", "1.1", "1.0", "Disabled"], var.mssql_server_minimum_tls_version)
    error_message = "Invalid value provided."
  }
}

variable "mssql_server_administrator_username" {
  type    = string
  default = "Magnum"
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
    name           = string
    sku_name       = string
    collation      = string
    license_type   = string
    max_size_gb    = string
    read_scale     = string
    zone_redundant = string
    create_mode    = string
    
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
}

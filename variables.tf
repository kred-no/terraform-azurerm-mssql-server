////////////////////////
// External Resources
////////////////////////

variable "resource_group" {
  type = object({
    name     = string
    location = string
  })
}

variable "virtual_network" {
  type = object({
    name                = string
    resource_group_name = string
  })
}

////////////////////////
// Overrides | Key Vault
////////////////////////

variable "key_vault_sku_name" {
  type   = string
  deault = ""
}

////////////////////////
// Overrides | MSSQL Server
////////////////////////

variable "mssql_server_name" {
  type    = string
  default = ""
}

variable "mssql_server_version" {
  type    = string
  default = ""
}

variable "mssql_server_administrator_username" {
  type    = string
  default = ""
}

////////////////////////
// Overrides | MSSQL Databases
////////////////////////

variable "databases" {
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

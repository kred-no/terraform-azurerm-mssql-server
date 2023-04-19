variable "deployment_type" {
  description = <<-HEREDOC
    Choose to deploy SQL Server as a azure-sql-server, azure-sql-managed-instance or self-managed virtual machine running sql-server.
    Valid options: [azure-sql managed-instance virtual-machine].
    HEREDOC

  type    = string
  default = "azure-sql"

  validation {
    error_message = "Invalid value provided."

    condition = contains([
      "azure-sql",
      "managed-instance",
      "virtual-machine",
    ], var.deployment_type)
  }
}

////////////////////////
// External Resources
////////////////////////

variable "resource_group" {
  description = "N/A"

  type = object({
    name     = string
    location = string
  })
}

variable "virtual_network" {
  description = "N/A"

  type = object({
    name                = string
    resource_group_name = string
  })

  default = null
}

variable "tags" {
  description = "N/A"

  type    = map(string)
  default = {}
}

////////////////////////
// Subnet
////////////////////////

variable "subnet_name" {
  description = "N/A"

  type    = string
  default = "SqlVmSubnet"
}

variable "subnet_vnet_index" {
  description = "N/A"

  type    = number
  default = 0
}

variable "subnet_newbits" {
  description = "N/A"

  type    = number
  default = 2
}

variable "subnet_netnum" {
  description = "N/A"

  type    = number
  default = 0
}

variable "subnet_nsg_enabled" {
  description = "N/A"

  type    = bool
  default = true
}

variable "subnet_nsg_rules" {
  description = "N/A"

  type = list(object({
    name                       = string
    priority                   = number
    direction                  = optional(string, "Inbound")
    access                     = optional(string, "Allow")
    protocol                   = optional(string, "Tcp")
    source_port_range          = optional(string)
    source_address_prefix      = optional(string) // NOTE: Leave blank to target NIC Asg for Outbound traffic
    destination_port_range     = optional(string)
    destination_address_prefix = optional(string) // NOTE: Leave blank to target NIC Asg for Inbound traffic
  }))

  default = []
}

////////////////////////
// SQL Server
////////////////////////

variable "server_name" {
  description = "N/A"

  type    = string
  default = "mssql-srv"
}

variable "server_size" {
  description = "N/A"

  type    = string
  default = "Standard_B2ms"
}

variable "server_priority" {
  description = "N/A"

  type    = string
  default = "Regular"
}

variable "server_eviction_policy" {
  description = "N/A"

  type    = string
  default = null
}

variable "server_max_bid_price" {
  description = "N/A"

  type    = number
  default = -1
}

variable "server_source_image_reference" {
  description = "N/A"

  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = optional(string, "latest")
  })

  default = {
    publisher = "MicrosoftSQLServer"
    offer     = "sql2022-ws2022"
    sku       = "sqldev-gen2"
  }
}

variable "server_admin_username" {
  description = "N/A"

  type    = string
  default = "Magnum"
}

variable "server_admin_password" {
  description = "N/A"

  type    = string
  default = "PewPew@5000"
}

variable "server_os_disk" {
  description = "N/A"

  type = object({
    caching              = string
    storage_account_type = string
    disk_size_gb         = number
  })

  default = {
    caching              = "ReadOnly"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 127
  }
}

variable "server_timezone" {
  description = "See https://jackstromberg.com/2017/01/list-of-time-zones-consumed-by-azure/"

  type    = string
  default = "W. Europe Standard Time"
}

////////////////////////
// SQL Instance
////////////////////////

variable "sql_license_type" {
  description = "N/A"

  type    = string
  default = "PAYG"
}

variable "sql_r_services_enabled" {
  description = "N/A"

  type    = bool
  default = null
}

variable "sql_connectivity_port" {
  description = "N/A"

  type    = number
  default = 1433
}

variable "sql_connectivity_type" {
  description = "N/A"

  type    = string
  default = "PRIVATE"
}

variable "sql_auto_backup" {
  description = "N/A"

  type = object({
    encryption_enabled              = optional(bool)
    encryption_password             = optional(string)
    retention_period_in_days        = optional(number)
    storage_blob_endpoint           = optional(string)
    storage_account_access_key      = optional(string)
    system_databases_backup_enabled = optional(bool)

    manual_schedule = optional(object({
      full_backup_frequency           = string
      full_backup_start_hour          = number
      full_backup_window_in_hours     = number
      log_backup_frequency_in_minutes = number
      days_of_week                    = list(string)
    }), null)
  })

  default = null
}

variable "sql_auto_patching" {
  description = "N/A"

  type = object({
    day_of_week                            = list(string)
    maintenance_window_starting_hour       = number
    maintenance_window_duration_in_minutes = number
  })

  default = null
}

variable "sql_instance" {
  description = "N/A"

  type = object({
    adhoc_workloads_optimization_enabled = optional(bool)
    collation                            = optional(string)
    instant_file_initialization_enabled  = optional(bool)
    lock_pages_in_memory_enabled         = optional(bool)
    max_dop                              = optional(number)
    max_server_memory_mb                 = optional(number)
    min_server_memory_mb                 = optional(number)
  })

  default = null
}

variable "sql_key_vault_credential" {
  description = "N/A"

  type = object({
    name                     = string
    key_vault_url            = string
    service_principal_name   = string
    service_principal_secret = string
  })

  default = null
}

variable "sql_assessment" {
  description = "N/A"

  type = object({
    enabled         = bool
    run_immediately = optional(bool)

    schedule = optional(object({
      weekly_interval    = number
      monthly_occurrence = number
      day_of_week        = string
      start_time         = string
    }), null)
  })

  default = null
}

variable "sql_storage_configuration" {
  type = object({
    disk_type                      = optional(string, "NEW")
    storage_workload_type          = optional(string, "OLTP")
    system_db_on_data_disk_enabled = optional(bool, false)
    use_managed_datadisk           = optional(bool, true)
    use_managed_logdisk            = optional(bool, true)
  })

  default = {}
}

////////////////////////
// Key Vault
////////////////////////

/*variable "prefix" {
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
// Storage Account
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
*/
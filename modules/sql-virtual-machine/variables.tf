////////////////////////
// MODULE TESTING
////////////////////////

variable "optional_extensions" {
  type = object({
    bginfo_enabled = optional(bool, true)
    bginfo_version = optional(string, "2.2")
  })

  default = {}
}

////////////////////////
// External
////////////////////////

variable "resource_group" {
  type = object({
    name = string
  })
}

variable "virtual_network" {
  type = object({
    name                = string
    resource_group_name = string
  })
}

variable "tags" {
  type    = map(string)
  default = {}
}

////////////////////////
// Network
////////////////////////

variable "subnet_name" {
  type = string
}

variable "subnet_vnet_index" {
  type = number
}

variable "subnet_newbits" {
  type = number
}

variable "subnet_netnum" {
  type = number
}

variable "subnet_nsg_enabled" {
  type = bool
}

variable "subnet_nsg_rules" {
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = optional(string, "Inbound")
    access                     = optional(string, "Allow")
    protocol                   = optional(string, "Tcp")
    source_port_range          = optional(string)
    source_address_prefix      = optional(string)
    destination_port_range     = optional(string)
    destination_address_prefix = optional(string)
  }))
}

////////////////////////
// SQL Server
////////////////////////

variable "server_name" {
  type = string
}

variable "server_size" {
  type = string
}

variable "server_priority" {
  type = string
}

variable "server_eviction_policy" {
  type = string
}

variable "server_max_bid_price" {
  type = number
}

variable "server_source_image_reference" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
}

variable "server_admin_username" {
  type = string
}

variable "server_admin_password" {
  type = string
}

variable "server_os_disk" {

  type = object({
    caching              = string
    storage_account_type = string
    disk_size_gb         = number
  })
}

variable "server_timezone" {
  type = string
}

////////////////////////
// SQL Instance
////////////////////////

variable "sql_license_type" {
  type = string
}

variable "sql_r_services_enabled" {
  type = bool
}

variable "sql_connectivity_port" {
  type = number
}

variable "sql_connectivity_type" {
  type = string
}

variable "sql_auto_backup" {
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
}

variable "sql_auto_patching" {
  type = object({
    day_of_week                            = list(string)
    maintenance_window_starting_hour       = number
    maintenance_window_duration_in_minutes = number
  })
}

variable "sql_instance" {
  type = object({
    adhoc_workloads_optimization_enabled = optional(bool)
    collation                            = optional(string)
    instant_file_initialization_enabled  = optional(bool)
    lock_pages_in_memory_enabled         = optional(bool)
    max_dop                              = optional(number)
    max_server_memory_mb                 = optional(number)
    min_server_memory_mb                 = optional(number)
  })
}

variable "sql_key_vault_credential" {
  type = object({
    name                     = string
    key_vault_url            = string
    service_principal_name   = string
    service_principal_secret = string
  })
}

variable "sql_assessment" {
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
}

variable "sql_storage_configuration" {
  type = object({
    disk_type                      = string
    storage_workload_type          = string
    system_db_on_data_disk_enabled = bool
    use_managed_datadisk           = bool
    use_managed_logdisk            = bool
    managed_datadisk_size_gb       = number
    managed_logdisk_size_gb        = number
  })
}

variable "sql_public_access_enabled" {
  type = bool
}

variable "sql_update_username" {
  type = string
}

variable "sql_update_password" {
  type = string
}
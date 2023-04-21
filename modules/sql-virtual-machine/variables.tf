////////////////////////
// External
////////////////////////

variable "resource_group" {}
variable "virtual_network" {}
variable "tags" {}
variable "key_vault" {}
variable "storage_account" {}

////////////////////////
// Network
////////////////////////

variable "subnet" {}
variable "nsg_rules" {}

////////////////////////
// Virtual Machine
////////////////////////

variable "vm_name" {}
variable "vm_size" {}
variable "vm_priority" {}
variable "vm_eviction_policy" {}
variable "vm_max_bid_price" {}
variable "vm_source_image_reference" {}
variable "vm_admin_username" {}
variable "vm_admin_password" {}
variable "vm_os_disk" {}
variable "vm_timezone" {}

////////////////////////
// SQL Server
////////////////////////

variable "sql_update_username" {}
variable "sql_update_password" {}
variable "sql_license_type" {}
variable "sql_r_services_enabled" {}
variable "sql_connectivity_port" {}
variable "sql_connectivity_type" {}

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
    day_of_week                            = string
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

////////////////////////
// Virtual Machine Extensions
////////////////////////

variable "vm_extension_aad_login" {}
variable "vm_extension_bginfo" {}
variable "vm_extension_compute_scripts" {}
variable "vm_extension_azure_scripts" {}

variable "deployment_type" {
  description = <<-HEREDOC
  Choose to deploy SQL Server as a azure-sql-server, azure-sql-managed-instance or self-managed virtual machine running sql-server.
  Valid options: [azure-sql managed-instance virtual-machine].
  HEREDOC

  type    = string
  default = "virtual-machine"

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
  description = <<-HEREDOC
  Reference to an EXISTING resource group to use for creating resources.
  The "Resource Group" name is globally unique, and must consist of 1-90 Characters.
  
  Valid character categories (UnicodeCategories):
    - UppercaseLetter
    - LowercaseLetter
    - TitlecaseLetter
    - ModifierLetter
    - OtherLetter
    - DecimalDigitNumber
  HEREDOC

  type = object({
    name     = string
    location = string
  })
}

variable "virtual_network" {
  description = <<-HEREDOC
  [virtual machine]
    Reference to an EXISTING virtual network.
    Any new network-related resources will be created in the same resource group as this virtual network.
  HEREDOC

  type = object({
    name                = string
    resource_group_name = string
  })

  default = null
}

variable "tags" {
  description = "Tags added for ALL new resources."

  type    = map(string)
  default = {}
}

////////////////////////
// Subnet
////////////////////////

variable "subnet" {
  description = <<-HEREDOC
  [virtual machine]
    Creates a new subnet. NSG can optionally be disabled.
    The 'vnet_index', 'newbits' and 'netnum' defines a subnet prefix, using terraform the function 'cidrsubnet'.
    
    Examples, using the VNet ["192.168.168.0/24", "10.0.0.0/16"]
      > [vnet_index = 0][newbits = 2][netnum = 0] : cidrsubnet("192.168.168.0/24", 2, 0) = "192.168.168.0/26"
      > [vnet_index = 1][newbits = 8][netnum = 1] : cidrsubnet("10.0.0.0/24", 8, 1)      = "10.0.1.0/24"
  HEREDOC

  type = object({
    name        = optional(string, "SqlVirtualMachineSubnet")
    nsg_enabled = optional(bool, true)
    vnet_index  = optional(number, 0)
    newbits     = optional(number, 2)
    netnum      = optional(number, 0)
  })

  default = {}
}

variable "nsg_rules" {
  description = <<-HEREDOC
  [virtual machine]
    User defined NSG rules to add to the subnet.
    - 'Inbound' destination defaults to the application security group of the host server network interface, unless an address is provided.
    - 'Outbound' source defaults to the application security group of the host server network interface, unless an address is provided.
  HEREDOC

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
// Virtual Machine
////////////////////////

variable "vm_name" {
  description = "N/A"

  type    = string
  default = "sqlsrv"
}

variable "vm_operating_system" {
  description = "Only 'Windows' supported (for now)."

  type    = string
  default = "Windows"
}

variable "vm_size" {
  description = "The VM size to use."

  type    = string
  default = "Standard_B2ms"
}

variable "vm_priority" {
  description = "The VM priority (i.e. 'Spot-or-Not')."

  type    = string
  default = "Regular"
}

variable "vm_eviction_policy" {
  description = "Deallocation, when using Spot instance."

  type    = string
  default = null
}

variable "vm_max_bid_price" {
  description = "N/A"

  type    = number
  default = null
}

variable "vm_source_image_reference" {
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

variable "vm_admin_username" {
  description = "N/A"

  type    = string
  default = "Superman"
}

variable "vm_admin_password" {
  description = "N/A"

  type    = string
  default = "IAmCl@rkK3nt"
}

variable "vm_os_disk" {
  description = "N/A"

  type = object({
    caching              = optional(string, "ReadOnly")
    storage_account_type = optional(string, "Standard_LRS")
    disk_size_gb         = optional(number, 127)
  })

  default = {}
}

variable "vm_timezone" {
  description = "See https://jackstromberg.com/2017/01/list-of-time-zones-consumed-by-azure/"

  type    = string
  default = "W. Europe Standard Time"
}

////////////////////////
// Virtual Machine Extensions
////////////////////////

variable "vm_extension_bginfo" {
  description = "az vm extension image list -o table --name BGInfo --publisher Microsoft.Compute --location <location>"

  type = object({
    enabled                    = optional(bool, true)
    type_handler_version       = optional(string, "2.2")
    auto_upgrade_minor_version = optional(bool, true)
    automatic_upgrade_enabled  = optional(bool, false)
  })

  default = {}
}

variable "vm_extension_aad_login" {
  description = "az vm extension image list -o table --name AADLoginForWindows --publisher Microsoft.Azure.ActiveDirectory --location <location>"

  type = object({
    enabled                    = optional(bool, true)
    type_handler_version       = optional(string, "2.0")
    auto_upgrade_minor_version = optional(bool, true)
    automatic_upgrade_enabled  = optional(bool, false)
  })

  default = {}
}

variable "vm_extension_compute_scripts" {
  description = "az vm extension image list -o table --name CustomScriptExtension --publisher Microsoft.Compute --location <location>"

  type = list(object({
    type_handler_version        = optional(string, "1.10")
    auto_upgrade_minor_version  = optional(bool, true)
    automatic_upgrade_enabled   = optional(bool, false)
    failure_suppression_enabled = optional(bool, false)

    name    = string
    command = string
  }))

  default = []

  /*default = [{
    name    = "AADJPrivate"
    command = "powershell.exe -Command \"New-Item -Force -Path HKLM:\\SOFTWARE\\Microsoft\\RDInfraAgent\\AADJPrivate\"; shutdown -r -t 15; exit 0"
  }]*/
}

variable "vm_extension_azure_scripts" {
  description = "az vm extension image list -o table --name CustomScript --publisher Microsoft.Azure.Extensions --location <location>"

  type = list(object({
    type_handler_version        = optional(string, "2.1")
    auto_upgrade_minor_version  = optional(bool, true)
    automatic_upgrade_enabled   = optional(bool, false)
    failure_suppression_enabled = optional(bool, false)

    name                 = string
    command              = string
    storage_account_name = optional(string, "")
    storage_account_key  = optional(string, "")
    managed_identity     = optional(map(string), {})
    file_uris            = optional(list(string), [])
  }))

  default = []
}

////////////////////////
// SQL Server Configuration
////////////////////////

variable "sql_update_username" {
  type    = string
  default = "BruceWayne"
}

variable "sql_update_password" {
  type    = string
  default = "!!IAmB@tman!!"
}

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
    day_of_week                            = string
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
    managed_datadisk_size_gb       = optional(number, 500)
    managed_logdisk_size_gb        = optional(number, 500)
  })

  default = {}
}

////////////////////////
// Load Balancer
////////////////////////

variable "private_link_enabled" {
  type    = bool
  default = false
}

variable "nat_rules" {
  type = list(object({
    name          = string
    frontend_port = number
    backend_port  = number
    protocol      = optional(string, "Tcp")
  }))

  default = []
}

variable "nat_pool_rules" {
  type = list(object({
    name                = string
    frontend_port_start = number
    frontend_port_end   = number
    backend_port        = number
    protocol            = optional(string, "Tcp")
  }))

  default = []
}

variable "lb_rules" {
  type = list(object({
    name                  = string
    frontend_port         = number
    backend_port          = number
    protocol              = optional(string, "Tcp")
    disable_outbound_snat = optional(bool, false)
    probe_enabled         = optional(bool, false)
    probe_protocol        = optional(string, "Tcp")
    probe_port            = optional(number)
    interval_in_seconds   = optional(number, 60)
    number_of_probes      = optional(number, 2)
    probe_threshold       = optional(number, 1)
  }))

  default = []
}

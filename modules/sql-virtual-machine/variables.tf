////////////////////////
// External
////////////////////////

variable "resource_group" {}
variable "virtual_network" {}
variable "nat_gateway" {}
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
variable "sql_auto_backup" {}
variable "sql_auto_patching" {}
variable "sql_instance" {}
variable "sql_key_vault_credential" {}
variable "sql_assessment" {}
variable "sql_storage_configuration" {}

////////////////////////
// Virtual Machine Extensions
////////////////////////

variable "vm_extension_aad_login" {}
variable "vm_extension_bginfo" {}
variable "vm_extension_compute_scripts" {}
variable "vm_extension_azure_scripts" {}

////////////////////////
// Sources
////////////////////////
// N/A

////////////////////////
// SQL Virtual Machine
////////////////////////

module "SQL_VIRTUAL_MACHINE" {
  count  = var.deployment_type != "virtual-machine" ? 0 : 1
  source = "./modules/sql-virtual-machine"

  subnet_name        = var.subnet_name
  subnet_vnet_index  = var.subnet_vnet_index
  subnet_newbits     = var.subnet_newbits
  subnet_netnum      = var.subnet_netnum
  subnet_nsg_enabled = var.subnet_nsg_enabled
  subnet_nsg_rules   = var.subnet_nsg_rules

  server_name                   = var.server_name
  server_size                   = var.server_size
  server_priority               = var.server_priority
  server_eviction_policy        = var.server_eviction_policy
  server_max_bid_price          = var.server_max_bid_price
  server_timezone               = var.server_timezone
  server_source_image_reference = var.server_source_image_reference
  server_os_disk                = var.server_os_disk
  server_admin_username         = var.server_admin_username
  server_admin_password         = var.server_admin_password

  sql_license_type          = var.sql_license_type
  sql_r_services_enabled    = var.sql_r_services_enabled
  sql_connectivity_port     = var.sql_connectivity_port
  sql_connectivity_type     = var.sql_connectivity_type
  sql_auto_backup           = var.sql_auto_backup
  sql_auto_patching         = var.sql_auto_patching
  sql_instance              = var.sql_instance
  sql_key_vault_credential  = var.sql_key_vault_credential
  sql_assessment            = var.sql_assessment
  sql_storage_configuration = var.sql_storage_configuration
  sql_public_access_enabled = var.sql_public_access_enabled
  sql_update_username       = var.sql_update_username
  sql_update_password       = var.sql_update_password

  // References
  tags            = var.tags
  resource_group  = var.resource_group
  virtual_network = var.virtual_network
}

////////////////////////
// Azure SQL
////////////////////////
// N/A

////////////////////////
// Azure SQL Managed Instance
////////////////////////
// N/A

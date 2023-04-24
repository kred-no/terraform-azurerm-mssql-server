////////////////////////
// Conditionals
////////////////////////

locals {
  flags = {
    managed_datadisk_enabled = var.sql_storage_configuration.use_managed_datadisk
    managed_logdisk_enabled  = var.sql_storage_configuration.use_managed_logdisk
  }
}

////////////////////////
// Data Sources
////////////////////////

data "azurerm_resource_group" "MAIN" {
  name = var.resource_group.name
}

data "azurerm_virtual_network" "MAIN" {
  name                = var.subnet.virtual_network_name
  resource_group_name = var.subnet.resource_group_name
}

data "azurerm_subnet" "MAIN" {
  name                 = var.subnet.name
  virtual_network_name = var.subnet.virtual_network_name
  resource_group_name  = var.subnet.resource_group_name
}

data "azurerm_storage_account" "MAIN" {
  count = var.storage_account != null ? 1 : 0

  name                = var.storage_account.name
  resource_group_name = var.storage_account.resource_group_name
}

data "azurerm_key_vault" "MAIN" {
  count = var.key_vault != null ? 1 : 0

  name                = var.key_vault.name
  resource_group_name = var.key_vault.resource_group_name
}

////////////////////////
// Random Password(s)
////////////////////////
// TODO

////////////////////////
// Network Interface
////////////////////////

resource "azurerm_network_interface" "MAIN" {
  name = join("-", [var.vm_name, "nic"])

  ip_configuration {
    name                          = join("-", [var.vm_name, "ipcfg"])
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = data.azurerm_subnet.MAIN.id
  }

  tags                = var.tags
  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

////////////////////////
// Application Security Group (ASG)
////////////////////////

resource "azurerm_application_security_group" "MAIN" {
  name                = join("-", [var.vm_name, "asg"])
  tags                = var.tags
  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_network_interface_application_security_group_association" "MAIN" {
  network_interface_id          = azurerm_network_interface.MAIN.id
  application_security_group_id = azurerm_application_security_group.MAIN.id
}

////////////////////////
// Managed Disks
////////////////////////

resource "azurerm_managed_disk" "DATADISK" {
  count = local.flags.managed_datadisk_enabled ? 1 : 0

  name                 = join("-", [var.vm_name, "datadisk"])
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.sql_storage_configuration.managed_datadisk_size_gb

  tags                = var.tags
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

resource "azurerm_managed_disk" "LOGDISK" {
  count = local.flags.managed_logdisk_enabled ? 1 : 0

  name                 = join("-", [var.vm_name, "logdisk"])
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.sql_storage_configuration.managed_logdisk_size_gb

  tags                = var.tags
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

////////////////////////
// SQL Server Virtual Machine
////////////////////////

resource "azurerm_windows_virtual_machine" "MAIN" {
  depends_on = [ // Create disks before creating VM
    azurerm_managed_disk.DATADISK,
    azurerm_managed_disk.LOGDISK,
  ]

  name            = var.vm_name
  size            = var.vm_size
  timezone        = var.vm_timezone
  admin_username  = var.vm_admin_username
  admin_password  = var.vm_admin_password
  priority        = var.vm_priority
  eviction_policy = var.vm_eviction_policy
  max_bid_price   = var.vm_max_bid_price

  network_interface_ids = [
    azurerm_network_interface.MAIN.id,
  ]

  identity {
    type = "SystemAssigned"
  }

  dynamic "source_image_reference" {
    for_each = var.vm_source_image_reference[*]

    content {
      publisher = source_image_reference.value["publisher"]
      offer     = source_image_reference.value["offer"]
      sku       = source_image_reference.value["sku"]
      version   = source_image_reference.value["version"]
    }
  }

  dynamic "os_disk" {
    for_each = var.vm_os_disk[*]

    content {
      name                 = join("-", [var.vm_name, "osdisk"])
      caching              = os_disk.value["caching"]
      storage_account_type = os_disk.value["storage_account_type"]
      disk_size_gb         = os_disk.value["disk_size_gb"]
    }
  }

  provision_vm_agent       = true
  enable_automatic_updates = true

  tags                = var.tags
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

resource "azurerm_virtual_machine_data_disk_attachment" "DATADISK" {
  count = local.flags.managed_datadisk_enabled ? 1 : 0

  lun                = 1
  caching            = "ReadWrite"
  virtual_machine_id = azurerm_windows_virtual_machine.MAIN.id
  managed_disk_id    = one(azurerm_managed_disk.DATADISK[*].id)
}

resource "azurerm_virtual_machine_data_disk_attachment" "LOGDISK" {
  count = local.flags.managed_logdisk_enabled ? 1 : 0

  lun                = 2
  caching            = "ReadWrite"
  virtual_machine_id = azurerm_windows_virtual_machine.MAIN.id
  managed_disk_id    = one(azurerm_managed_disk.LOGDISK[*].id)
}

////////////////////////
// Key Vault Access Policy
////////////////////////

/*resource "azurerm_key_vault_access_policy" "MAIN" {
  key_vault_id = var.key_vault.id
  tenant_id    = azurerm_windows_virtual_machine.MAIN.identity.0.tenant_id
  object_id    = azurerm_windows_virtual_machine.MAIN.identity.0.principal_id

  key_permissions     = ["Get", "Purge"]
  secret_permissions  = ["Get", "Delete", "Purge"]
  storage_permissions = ["Get", "List", "Set", "SetSAS", "GetSAS", "DeleteSAS", "Update", "RegenerateKey"]
}*/

////////////////////////
// SQL Server Instance
////////////////////////

resource "azurerm_mssql_virtual_machine" "MAIN" {
  sql_license_type                 = var.sql_license_type
  r_services_enabled               = var.sql_r_services_enabled
  sql_connectivity_port            = var.sql_connectivity_port
  sql_connectivity_type            = var.sql_connectivity_type
  sql_connectivity_update_username = var.sql_update_username
  sql_connectivity_update_password = var.sql_update_password

  dynamic "sql_instance" {
    for_each = var.sql_instance[*]

    content {
      adhoc_workloads_optimization_enabled = sql_instance.value["adhoc_workloads_optimization_enabled"]
      collation                            = sql_instance.value["collation"]
      instant_file_initialization_enabled  = sql_instance.value["instant_file_initialization_enabled"]
      lock_pages_in_memory_enabled         = sql_instance.value["lock_pages_in_memory_enabled"]
      max_dop                              = sql_instance.value["max_dop"]
      max_server_memory_mb                 = sql_instance.value["max_vm_memory_mb"]
      min_server_memory_mb                 = sql_instance.value["min_vm_memory_mb"]
    }
  }

  storage_configuration {
    disk_type                      = var.sql_storage_configuration.disk_type
    storage_workload_type          = var.sql_storage_configuration.storage_workload_type
    system_db_on_data_disk_enabled = var.sql_storage_configuration.system_db_on_data_disk_enabled

    data_settings {
      default_file_path = local.flags.managed_datadisk_enabled ? "F:\\Data" : "C:\\Data"
      luns              = local.flags.managed_datadisk_enabled ? [one(azurerm_virtual_machine_data_disk_attachment.DATADISK[*].lun)] : []
    }

    log_settings {
      default_file_path = local.flags.managed_logdisk_enabled ? "G:\\Log" : "C:\\Log"
      luns              = local.flags.managed_logdisk_enabled ? [one(azurerm_virtual_machine_data_disk_attachment.LOGDISK[*].lun)] : []
    }

    temp_db_settings {
      default_file_path = "D:\\TempDb" // Ephemeral disk
      luns              = []
    }
  }

  dynamic "key_vault_credential" {
    for_each = var.sql_key_vault_credential[*]

    content {
      name                     = key_vault_credential.value["name"]
      key_vault_url            = key_vault_credential.value["key_vault_url"]
      service_principal_name   = key_vault_credential.value["service_principal_name"]
      service_principal_secret = key_vault_credential.value["service_principal_secret"]
    }
  }

  dynamic "assessment" {
    for_each = var.sql_assessment[*]

    content {
      enabled         = assessment.value["enabled"]
      run_immediately = assessment.value["run_immediately"]

      dynamic "schedule" {
        for_each = assessment.value["schedule"][*]

        content {
          weekly_interval    = schedule.value["weekly_interval"]
          monthly_occurrence = schedule.value["monthly_occurrence"]
          day_of_week        = schedule.value["day_of_week"]
          start_time         = schedule.value["start_time"]
        }
      }
    }
  }

  dynamic "auto_patching" {
    for_each = var.sql_auto_patching[*]

    content {
      day_of_week                            = auto_patching.value["day_of_week"]
      maintenance_window_starting_hour       = auto_patching.value["maintenance_window_starting_hour"]
      maintenance_window_duration_in_minutes = auto_patching.value["maintenance_window_duration_in_minutes"]
    }
  }

  dynamic "auto_backup" {
    for_each = var.sql_auto_backup[*]

    content {
      encryption_enabled              = auto_backup.value["encryption_enabled"]
      encryption_password             = auto_backup.value["encryption_password"]
      retention_period_in_days        = auto_backup.value["retention_period_in_days"]
      storage_blob_endpoint           = auto_backup.value["storage_blob_endpoint"]
      storage_account_access_key      = auto_backup.value["storage_account_access_key"]
      system_databases_backup_enabled = auto_backup.value["system_databases_backup_enabled"]

      dynamic "manual_schedule" {
        for_each = auto_backup.value["manual_schedule"][*]

        content {
          full_backup_frequency           = manual_schedule.value["full_backup_frequency"]
          full_backup_start_hour          = manual_schedule.value["full_backup_start_hour"]
          full_backup_window_in_hours     = manual_schedule.value["full_backup_window_in_hours"]
          log_backup_frequency_in_minutes = manual_schedule.value["log_backup_frequency_in_minutes"]
          days_of_week                    = manual_schedule.value["days_of_week"]
        }
      }
    }
  }

  tags               = var.tags
  virtual_machine_id = azurerm_windows_virtual_machine.MAIN.id
}

////////////////////////
// VM Extensions | AAD Registration
////////////////////////

resource "azurerm_virtual_machine_extension" "AAD_LOGIN" {
  count      = var.vm_extension_aad_login.enabled ? 1 : 0
  depends_on = [azurerm_mssql_virtual_machine.MAIN] // Create after MSSQL server deployed

  name      = "AADLogin"
  publisher = "Microsoft.Azure.ActiveDirectory"
  type      = "AADLoginForWindows"

  type_handler_version       = var.vm_extension_aad_login.type_handler_version
  auto_upgrade_minor_version = var.vm_extension_aad_login.auto_upgrade_minor_version
  automatic_upgrade_enabled  = var.vm_extension_aad_login.automatic_upgrade_enabled

  // terraform-provider-azurerm Issue #7748 - Bug in AAD Extension
  // See:
  // - https://www.rozemuller.com/how-to-join-azure-ad-automated/
  // - https://github.com/hashicorp/terraform-provider-azurerm/issues/7748
  //
  //  Intune mdmId: "0000000a-0000-0000-c000-000000000000"
  //  VM mdmId: azurerm_windows_virtual_machine.MAIN.identity.0.principal_id ?
  #settings = jsonencode({
  #  "mdmId" = "0000000a-0000-0000-c000-000000000000"
  #})

  /*protected_settings = jsonencode({})*/

  tags               = var.tags
  virtual_machine_id = azurerm_windows_virtual_machine.MAIN.id

  lifecycle {
    ignore_changes = [settings, protected_settings]
  }
}

////////////////////////
// VM Extensions | BG Info
////////////////////////

resource "azurerm_virtual_machine_extension" "BGINFO" {
  count      = var.vm_extension_bginfo.enabled ? 1 : 0
  depends_on = [azurerm_mssql_virtual_machine.MAIN] // Create after MSSQL server deployed

  name      = "BGInfo"
  publisher = "Microsoft.Compute"
  type      = "BGInfo"

  type_handler_version       = var.vm_extension_bginfo.type_handler_version
  auto_upgrade_minor_version = var.vm_extension_bginfo.auto_upgrade_minor_version
  automatic_upgrade_enabled  = var.vm_extension_bginfo.automatic_upgrade_enabled

  tags               = var.tags
  virtual_machine_id = azurerm_windows_virtual_machine.MAIN.id

  lifecycle {
    ignore_changes = []
  }
}

////////////////////////
// VM Extensions | Custom Azure Script(s)
////////////////////////

resource "azurerm_virtual_machine_extension" "AZURE_CUSTOM_SCRIPT" {
  for_each = {
    for script in var.vm_extension_azure_scripts : script.name => script
  }

  depends_on = [azurerm_mssql_virtual_machine.MAIN]

  name      = each.key
  publisher = "Microsoft.Azure.Extensions"
  type      = "CustomScript"

  type_handler_version        = each.value["type_handler_version"]
  auto_upgrade_minor_version  = each.value["auto_upgrade_minor_version"]
  automatic_upgrade_enabled   = each.value["automatic_upgrade_enabled"]
  failure_suppression_enabled = each.value["failure_suppression_enabled"]

  protected_settings = jsonencode({
    "commandToExecute"   = each.value["command"]
    "storageAccountName" = each.value["storage_account_name"]
    "storageAccountKey"  = each.value["storage_account_key"]
    "managedIdentity"    = each.value["managed_identity"]
    "fileUris"           = each.value["file_uris"]
  })

  tags               = var.tags
  virtual_machine_id = azurerm_windows_virtual_machine.MAIN.id

  lifecycle {
    ignore_changes = [settings, protected_settings]
  }
}

////////////////////////
// VM Extensions | Custom Compute Script(s)
////////////////////////

resource "azurerm_virtual_machine_extension" "COMPUTE_CUSTOM_SCRIPT" {
  for_each = {
    for script in var.vm_extension_compute_scripts : script.name => script
  }

  depends_on = [azurerm_mssql_virtual_machine.MAIN] // Create after MSSQL server deployed

  name      = each.key
  publisher = "Microsoft.Compute"
  type      = "CustomScriptExtension"

  type_handler_version        = each.value["type_handler_version"]
  auto_upgrade_minor_version  = each.value["auto_upgrade_minor_version"]
  automatic_upgrade_enabled   = each.value["automatic_upgrade_enabled"]
  failure_suppression_enabled = each.value["failure_suppression_enabled"]

  settings = jsonencode({
    "commandToExecute" = each.value["command"]
  })

  tags               = var.tags
  virtual_machine_id = azurerm_windows_virtual_machine.MAIN.id

  lifecycle {
    ignore_changes = [settings, protected_settings]
  }
}

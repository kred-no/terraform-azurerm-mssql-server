////////////////////////
// Sources
////////////////////////

data "azurerm_resource_group" "MAIN" {
  name = var.resource_group.name
}

data "azurerm_virtual_network" "MAIN" {
  name                = var.virtual_network.name
  resource_group_name = var.virtual_network.resource_group_name
}

////////////////////////
// Resources | Network
////////////////////////

resource "azurerm_subnet" "MAIN" {
  name = var.subnet_name

  address_prefixes = [cidrsubnet(
    element(data.azurerm_virtual_network.MAIN.address_space, var.subnet_vnet_index),
    var.subnet_newbits,
    var.subnet_netnum,
  )]

  virtual_network_name = data.azurerm_virtual_network.MAIN.name
  resource_group_name  = data.azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_network_interface" "MAIN" {
  name = join("-", [var.server_name, "nic"])

  ip_configuration {
    name                          = join("-", [var.server_name, "ipcfg"])
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.MAIN.id
    #public_ip_address_id          = var.server_public_access ? xxx : null
  }

  tags                = var.tags
  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_application_security_group" "MAIN" {
  count = var.subnet_nsg_enabled ? 1 : 0

  name                = join("-", [var.server_name, "asg"])
  tags                = var.tags
  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_network_interface_application_security_group_association" "MAIN" {
  count = var.subnet_nsg_enabled ? 1 : 0

  network_interface_id          = azurerm_network_interface.MAIN.id
  application_security_group_id = one(azurerm_application_security_group.MAIN[*].id)
}

resource "azurerm_network_security_group" "MAIN" {
  count = var.subnet_nsg_enabled ? 1 : 0

  name                = join("-", [azurerm_subnet.MAIN.name, "nsg"])
  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "MAIN" {
  count = var.subnet_nsg_enabled ? 1 : 0

  subnet_id                 = azurerm_subnet.MAIN.id
  network_security_group_id = one(azurerm_network_security_group.MAIN[*].id)
}

resource "azurerm_network_security_rule" "MAIN" {
  for_each = {
    for rule in var.subnet_nsg_rules : join("", [rule.direction, rule.priority]) => rule
    if var.subnet_nsg_enabled
  }

  name      = each.value["name"]
  priority  = each.value["priority"]
  direction = each.value["direction"]
  access    = each.value["access"]
  protocol  = each.value["protocol"]

  source_port_range     = each.value["source_port_range"]
  source_address_prefix = each.value["source_address_prefix"]

  source_application_security_group_ids = flatten([
    anytrue([
      each.value["direction"] != "Outbound",
      each.value["source_address_prefix"] != null,
    ]) ? [] : [one(azurerm_application_security_group.MAIN[*])]
  ])

  destination_port_range     = each.value["destination_port_range"]
  destination_address_prefix = each.value["destination_address_prefix"]

  destination_application_security_group_ids = flatten([
    anytrue([
      each.value["direction"] != "Inbound",
      each.value["destination_address_prefix"] != null,
    ]) ? [] : [one(azurerm_application_security_group.MAIN[*])]
  ])

  network_security_group_name = one(azurerm_network_security_group.MAIN[*].name)
  resource_group_name         = data.azurerm_virtual_network.MAIN.resource_group_name
}

////////////////////////
// Managed Disks
////////////////////////

resource "azurerm_managed_disk" "DATADISK" {
  count = var.sql_storage_configuration.use_managed_datadisk ? 1 : 0

  name                 = join("-", [var.server_name, "datadisk"])
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 300
  tags                 = var.tags
  location             = data.azurerm_resource_group.MAIN.location
  resource_group_name  = data.azurerm_resource_group.MAIN.name
}

resource "azurerm_managed_disk" "LOGDISK" {
  count = var.sql_storage_configuration.use_managed_logdisk ? 1 : 0

  name                 = join("-", [var.server_name, "logdisk"])
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 300
  tags                 = var.tags
  location             = data.azurerm_resource_group.MAIN.location
  resource_group_name  = data.azurerm_resource_group.MAIN.name
}

////////////////////////
// SQL Server Virtual Machine
////////////////////////

resource "azurerm_windows_virtual_machine" "MAIN" {

  depends_on = [ // Create disks before VM
    azurerm_managed_disk.DATADISK,
    azurerm_managed_disk.LOGDISK,
  ]

  name            = var.server_name
  size            = var.server_size
  timezone        = var.server_timezone
  admin_username  = var.server_admin_username
  admin_password  = var.server_admin_password
  priority        = var.server_priority
  eviction_policy = var.server_eviction_policy
  max_bid_price   = var.server_max_bid_price

  network_interface_ids = [
    azurerm_network_interface.MAIN.id,
  ]

  identity {
    type = "SystemAssigned"
  }

  dynamic "source_image_reference" {
    for_each = var.server_source_image_reference[*]

    content {
      publisher = source_image_reference.value["publisher"]
      offer     = source_image_reference.value["offer"]
      sku       = source_image_reference.value["sku"]
      version   = source_image_reference.value["version"]
    }
  }

  dynamic "os_disk" {
    for_each = var.server_os_disk[*]

    content {
      name                 = join("-", [var.server_name, "osdisk"])
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
  count = var.sql_storage_configuration.use_managed_datadisk ? 1 : 0

  lun                = 1
  caching            = "ReadWrite"
  virtual_machine_id = azurerm_windows_virtual_machine.MAIN.id
  managed_disk_id    = one(azurerm_managed_disk.DATADISK[*].id)
}

resource "azurerm_virtual_machine_data_disk_attachment" "LOGDISK" {
  count = var.sql_storage_configuration.use_managed_logdisk ? 1 : 0

  lun                = 2
  caching            = "ReadWrite"
  virtual_machine_id = azurerm_windows_virtual_machine.MAIN.id
  managed_disk_id    = one(azurerm_managed_disk.LOGDISK[*].id)
}

////////////////////////
// SQL Server Instance
////////////////////////

resource "azurerm_mssql_virtual_machine" "MAIN" {
  sql_license_type = var.sql_license_type

  r_services_enabled               = var.sql_r_services_enabled
  sql_connectivity_port            = var.sql_connectivity_port
  sql_connectivity_type            = var.sql_connectivity_type
  sql_connectivity_update_username = "Laban"
  sql_connectivity_update_password = "S2ig3m@nn"

  dynamic "sql_instance" {
    for_each = var.sql_instance[*]

    content {
      adhoc_workloads_optimization_enabled = sql_instance.value["adhoc_workloads_optimization_enabled"]
      collation                            = sql_instance.value["collation"]
      instant_file_initialization_enabled  = sql_instance.value["instant_file_initialization_enabled"]
      lock_pages_in_memory_enabled         = sql_instance.value["lock_pages_in_memory_enabled"]
      max_dop                              = sql_instance.value["max_dop"]
      max_server_memory_mb                 = sql_instance.value["max_server_memory_mb"]
      min_server_memory_mb                 = sql_instance.value["min_server_memory_mb"]
    }
  }

  storage_configuration {
    disk_type                      = var.sql_storage_configuration.disk_type
    storage_workload_type          = var.sql_storage_configuration.storage_workload_type
    system_db_on_data_disk_enabled = var.sql_storage_configuration.system_db_on_data_disk_enabled

    data_settings {
      default_file_path = var.sql_storage_configuration.use_managed_datadisk ? "F:\\Data" : "C:\\Data"
      luns              = var.sql_storage_configuration.use_managed_datadisk ? [one(azurerm_virtual_machine_data_disk_attachment.DATADISK[*].lun)] : []
    }

    log_settings {
      default_file_path = var.sql_storage_configuration.use_managed_logdisk ? "G:\\Log" : "C:\\Log"
      luns              = var.sql_storage_configuration.use_managed_logdisk ? [one(azurerm_virtual_machine_data_disk_attachment.LOGDISK[*].lun)] : []
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
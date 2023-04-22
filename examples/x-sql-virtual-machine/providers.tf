terraform {
  required_version = ">= 1.4.2"

  backend "local" {
    path = "./.state/basic-example.tfstate"
  }

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {

    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false // It's an SQL server ..
      skip_shutdown_and_force_delete = true  // Avoids SQL server API bug ..
    }
  }

  subscription_id = var.subscription_id // ARM_SUBSCRIPTION_ID
  tenant_id       = var.tenant_id       // ARM_TENANT_ID
}

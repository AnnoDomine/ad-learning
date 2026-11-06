terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.13.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.1"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_deleted_keys_on_destroy = true
      recover_soft_deleted_keys          = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

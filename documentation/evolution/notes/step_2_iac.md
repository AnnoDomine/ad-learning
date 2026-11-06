# Step 2 - IaC

## Confugrations

> Based on the [`azurerm` documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### Variables

```terraform
variable "az_rg_name" {
    description = "Name of the resource group"
    type = string
    default = "learningsteps-evo-lab-rg"
}
variable "az_region" {
    description = "Default cloud region"
    type = string
    default = "germanywestcentral"
}
variable "az_vnet_name" {
    description = "Name of the VNET"
    type = string
    default = "learningsteps-evo-vnet"
}
variable "az_sub_name" {
    description = "Name of the subnet"
    type = string
    default = "learningsteps-evo-sub-net"
}
variable "az_priv_dns" {
    description = "Name of the private DNS Zone"
    type = string
    default = "learningsteps-evo.postgres.database.azure.com"
}
variable "az_priv_dns_vnet_link" {
    description = "Name of the private DNS Zone VNET link"
    type = string
    default = "learningsteps-evo-priv-dns-vnet-link"
}
variable "az_aks_cluster" {
    description = "Name of the AKS cluster"
    type = string
    default = "learningsteps-evo-akcc"
}
variable "az_postgresql_server" {
    description = "Name of the DB"
    type = string
    default = "learningsteps-evo-postgresql"
}
variable "az_postgresql_user" {
    description = "Name of the DB admin user"
    type = string
    default = "evo_ls_psql"
}
variable "az_kv" {
    description = "Name of the Azure Key Vault"
    type = string
    default = "learningsteps-evo-kv"
}
variable "az_kv_cert" {
    description = "Name of the Azure Key Vault SSH Certification"
    type = string
    default = "learningsteps-evo-kv-cert"
}
```

### Main

```terraform
# Preparements

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

data "azurerm_client_config" "current" {}

provider "azurerm" {
  features {
      key_vault {
        purge_soft_deleted_keys_on_destroy = true
        recover_soft_deleted_keys          = true
      }
    }
}

# Random password generator

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_resource_group" "learningsteps_evo" {
  name     = var.az_rg_name
  location = var.az_region
}

resource "azurerm_virtual_network" "learningsteps_vnet" {
  name                = var.az_vnet_name
  resource_group_name = azurerm_resource_group.learningsteps_evo.name
  location            = azurerm_resource_group.learningsteps_evo.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "learningsteps_sn" {
  name                 = var.az_sub_name
  resource_group_name  = azurerm_resource_group.learningsteps_evo.name
  virtual_network_name = azurerm_virtual_network.learningsteps_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoint {
    service = "Microsoft.Storage"
  }
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "learningsteps_priv_dns" {
  name                = var.az_priv_dns
  resource_group_name = azurerm_resource_group.learningsteps_evo.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "learningsteps_priv_dns_vn_link" {
  name                = var.az_priv_dns_vnet_link
  private_dns_zone_id = azurerm_private_dns_zone.learningsteps_priv_dns.id
  virtual_network_id  = azurerm_virtual_network.learningsteps_vnet.id
  depends_on          = [azurerm_subnet.learningsteps_sn]
}

# Key Vault

resource "azurerm_key_vault" "learningsteps_evo_key_vault" {
  name                       = var.az_kv
  location                   = azurerm_resource_group.learningsteps_evo.location
  resource_group_name        = azurerm_resource_group.learningsteps_evo.name
  rbac_authorization_enabled = false
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Delete",
      "Get",
      "Purge",
      "Recover",
      "Update",
      "GetRotationPolicy",
      "SetRotationPolicy"
    ]

    secret_permissions = [
      "Get",
      "Set",
      "List",
      "Delete",
      "Purge"
    ]
  }
}

resource "azurerm_key_vault_key" "generated" {
  name         = var.az_kv_cert
  key_vault_id = azurerm_key_vault.learningsteps_evo_key_vault.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }
}

resource "azurerm_key_vault_secret" "db_password" {
  name = "db-admin-password"
  value = random_password.password.result
  key_vault_id = azurerm_key_vault.learningsteps_evo_key_vault.id
} 

# Kubernetes cluster

resource "azurerm_kubernetes_cluster" "learningsteps_aks_cluster" {
  name                         = var.az_aks_cluster
  resource_group_name          = azurerm_resource_group.learningsteps_evo.name
  location                     = azurerm_resource_group.learningsteps_evo.location
  dns_prefix                   = "learningsteps-aks"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v6"
  }
}

# Postgresql DB

resource "azurerm_postgresql_flexible_server" "learningsteps_db" {
  name                          = var.az_postgresql_server
  resource_group_name           = azurerm_resource_group.learningsteps_evo.name
  location                      = azurerm_resource_group.learningsteps_evo.location
  version                       = "18"
  delegated_subnet_id           = azurerm_subnet.learningsteps_sn.id
  private_dns_zone_id           = azurerm_private_dns_zone.learningsteps_priv_dns.id
  public_network_access_enabled = false
  administrator_login           = var.az_postgresql_user
  administrator_password        = azurerm_key_vault_secret.db_password.value

  depends_on = [azurerm_private_dns_zone_virtual_network_link.learningsteps_priv_dns_vn_link]
}
```

## Additional

Add automated trivy check of terraform config in CI.

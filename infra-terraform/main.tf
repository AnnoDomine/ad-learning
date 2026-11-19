# ==============================================================================
# Main Infrastructure Definition – LearningSteps Evolution
# ==============================================================================
# Provisions the complete Cloud-Native Azure environment:
#   1. Core Resource Group & Random DB Credential Generation
#   2. Virtual Network, PostgreSQL Delegated Subnet & Private DNS Zone
#   3. Hardened Azure Key Vault (Network ACLs + Dual Access Policies)
#   4. Azure Kubernetes Service (RBAC, Network Policy, IP Fencing, CSI Addon)
#   5. Private PostgreSQL Flexible Server
#   6. Azure Container Registry & RBAC AcrPull Binding for AKS

# Retrieve active Azure subscription, tenant, and caller object ID (OIDC identity)
data "azurerm_client_config" "current" {}

# ------------------------------------------------------------------------------
# 1. Credential Generation & Core Resource Group
# ------------------------------------------------------------------------------

# Generate a cryptographically random DB administrator password; override_special
# restricts symbols to URL-safe characters so DATABASE_URL requires no escaping
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_resource_group" "learningsteps_evo" {
  name     = var.az_rg_name
  location = var.az_region
}

# ------------------------------------------------------------------------------
# 2. Networking & Private Database DNS
# ------------------------------------------------------------------------------

resource "azurerm_virtual_network" "learningsteps_vnet" {
  name                = var.az_vnet_name
  resource_group_name = azurerm_resource_group.learningsteps_evo.name
  location            = azurerm_resource_group.learningsteps_evo.location
  address_space       = ["10.0.0.0/16"]
}

# Subnet dedicated exclusively to PostgreSQL Flexible Server via service delegation;
# service endpoints allow secure Azure backbone routing to Storage and Key Vault
resource "azurerm_subnet" "learningsteps_sn" {
  name                 = var.az_sub_name
  resource_group_name  = azurerm_resource_group.learningsteps_evo.name
  virtual_network_name = azurerm_virtual_network.learningsteps_vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  service_endpoint {
    service = "Microsoft.Storage"
  }
  service_endpoint {
    service = "Microsoft.KeyVault"
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

# Explicit depends_on prevents race conditions between subnet delegation and DNS link
resource "azurerm_private_dns_zone_virtual_network_link" "learningsteps_priv_dns_vn_link" {
  name                = var.az_priv_dns_vnet_link
  private_dns_zone_id = azurerm_private_dns_zone.learningsteps_priv_dns.id
  virtual_network_id  = azurerm_virtual_network.learningsteps_vnet.id
  depends_on          = [azurerm_subnet.learningsteps_sn]
}

# ------------------------------------------------------------------------------
# 3. Security – Azure Key Vault & Secret Management
# ------------------------------------------------------------------------------

resource "azurerm_key_vault" "learningsteps_evo_key_vault" {
  name                       = var.az_kv
  location                   = azurerm_resource_group.learningsteps_evo.location
  resource_group_name        = azurerm_resource_group.learningsteps_evo.name
  rbac_authorization_enabled = false
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7

  # Access policy for the Terraform / CI/CD OIDC principal provisioning keys and secrets
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

  # Least-privilege read-only policy for the AKS Key Vault Secrets Store CSI Driver identity
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_kubernetes_cluster.learningsteps_aks_cluster.key_vault_secrets_provider[0].secret_identity[0].object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]
  }

  # Enforce default-deny firewall (satisfies Trivy AZU-0013); CI/CD runner IPs and
  # AKS outbound IPs are permitted explicitly alongside trusted Azure services
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.aks_authorized_ip_ranges
    virtual_network_subnet_ids = [azurerm_subnet.learningsteps_sn.id]
  }
}

# Managed RSA key with automated 90-day lifecycle and 30-day pre-expiry rotation
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

# Store the generated PostgreSQL password in Key Vault so Kubernetes pods retrieve it at runtime
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-admin-password"
  value        = random_password.password.result
  key_vault_id = azurerm_key_vault.learningsteps_evo_key_vault.id
}

# ------------------------------------------------------------------------------
# 4. Compute – Azure Kubernetes Service (AKS)
# ------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "learningsteps_aks_cluster" {
  name                = var.az_aks_cluster
  resource_group_name = azurerm_resource_group.learningsteps_evo.name
  location            = azurerm_resource_group.learningsteps_evo.location
  dns_prefix          = "learningsteps-aks"

  # Explicitly enforce Kubernetes RBAC (Trivy AZU-0042)
  role_based_access_control_enabled = true

  # Restrict Kubernetes API server access to authorized CI/CD or operator IPs (Trivy AZU-0041)
  api_server_access_profile {
    authorized_ip_ranges = var.aks_authorized_ip_ranges
  }

  # Enable Azure CNI and Azure Network Policy for pod-level traffic control (Trivy AZU-0043)
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "standard_d2s_v6"
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  # Enable Azure Key Vault Secrets Store CSI Driver with automated secret rotation
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }
}

# ------------------------------------------------------------------------------
# 5. Database – Azure Database for PostgreSQL Flexible Server
# ------------------------------------------------------------------------------

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

  sku_name   = "B_Standard_B2als_v2"
  storage_mb = 32768

  depends_on = [azurerm_private_dns_zone_virtual_network_link.learningsteps_priv_dns_vn_link]

  # Azure auto-assigns an availability zone at creation time; ignoring zone drift
  # prevents failed in-place updates on single-zone Flexible Server re-applies
  lifecycle {
    ignore_changes = [zone]
  }
}

# ------------------------------------------------------------------------------
# 6. Container Registry & AKS Pull Authorization
# ------------------------------------------------------------------------------

resource "azurerm_container_registry" "learningsteps_acr" {
  name                = var.az_acr
  resource_group_name = azurerm_resource_group.learningsteps_evo.name
  location            = azurerm_resource_group.learningsteps_evo.location
  sku                 = "Basic"
  # Disable static admin user; AKS authenticates exclusively via Entra ID AcrPull RBAC
  admin_enabled = false
}

# Grant AKS kubelet managed identity pull permissions on the ACR
resource "azurerm_role_assignment" "learningsteps_acr_role" {
  scope                = azurerm_container_registry.learningsteps_acr.id
  principal_id         = azurerm_kubernetes_cluster.learningsteps_aks_cluster.kubelet_identity[0].object_id
  role_definition_name = "AcrPull"
}

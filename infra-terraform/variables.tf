# ==============================================================================
# Input Variables – LearningSteps Evolution Infrastructure
# ==============================================================================

# ------------------------------------------------------------------------------
# Core & Networking
# ------------------------------------------------------------------------------

variable "az_rg_name" {
  description = "Name of the target Azure Resource Group containing all application infrastructure"
  type        = string
  default     = "learningsteps-evo-lab-rg"
}

variable "az_region" {
  description = "Default Azure region for provisioning all Evolution resources"
  type        = string
  default     = "westeurope"
}

variable "az_vnet_name" {
  description = "Name of the Virtual Network isolating database and private DNS connectivity"
  type        = string
  default     = "learningsteps-evo-vnet"
}

variable "az_sub_name" {
  description = "Name of the delegated subnet reserved for PostgreSQL Flexible Server"
  type        = string
  default     = "learningsteps-evo-sub-net"
}

variable "az_priv_dns" {
  description = "Private DNS zone name for internal PostgreSQL Flexible Server name resolution"
  type        = string
  default     = "learningsteps-evo.postgres.database.azure.com"
}

variable "az_priv_dns_vnet_link" {
  description = "Name of the Virtual Network link attaching the Private DNS Zone to the VNet"
  type        = string
  default     = "learningsteps-evo-priv-dns-vnet-link"
}

# ------------------------------------------------------------------------------
# Compute (Azure Kubernetes Service)
# ------------------------------------------------------------------------------

variable "az_aks_cluster" {
  description = "Name of the Azure Kubernetes Service (AKS) cluster"
  type        = string
  default     = "learningsteps-evo-akcc"
}

# Safe local fallback for `terraform validate` and offline Trivy IaC scans.
# Overridden dynamically in CI/CD via `TF_VAR_aks_authorized_ip_ranges` with the
# current GitHub Actions runner `/32` IP so `kubectl` can reach the API server.
variable "aks_authorized_ip_ranges" {
  description = "List of CIDR IP ranges allowed to access the AKS API server and Key Vault firewall"
  type        = list(string)
  default     = ["127.0.0.1/32"]
}

# ------------------------------------------------------------------------------
# Database (Azure Database for PostgreSQL Flexible Server)
# ------------------------------------------------------------------------------

variable "az_postgresql_server" {
  description = "Name of the Azure Database for PostgreSQL Flexible Server instance"
  type        = string
  default     = "learningsteps-evo-postgresql"
}

variable "az_postgresql_user" {
  description = "Administrator login username for the PostgreSQL Flexible Server"
  type        = string
  default     = "evo_ls_psql"
}

# ------------------------------------------------------------------------------
# Security (Azure Key Vault)
# ------------------------------------------------------------------------------

variable "az_kv" {
  description = "Globally unique name of the Azure Key Vault storing secrets and encryption keys"
  type        = string
  default     = "learningsteps-evo-kv"
}

variable "az_kv_cert" {
  description = "Name of the RSA key managed inside Azure Key Vault"
  type        = string
  default     = "learningsteps-evo-kv-cert"
}

# ------------------------------------------------------------------------------
# Container Registry (Azure Container Registry)
# ------------------------------------------------------------------------------

variable "az_acr" {
  description = "Globally unique Azure Container Registry name (alphanumeric lowercase only, 5-50 chars)"
  type        = string
  default     = "learningstepsevolabacr01"
}

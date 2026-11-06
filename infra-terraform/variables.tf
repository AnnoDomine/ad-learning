variable "az_rg_name" {
  description = "Name of the resource group"
  type        = string
  default     = "learningsteps-evo-lab-rg"
}

variable "az_region" {
  description = "Default cloud region"
  type        = string
  default     = "westeurope"
}

variable "az_vnet_name" {
  description = "Name of the VNET"
  type        = string
  default     = "learningsteps-evo-vnet"
}

variable "az_sub_name" {
  description = "Name of the subnet"
  type        = string
  default     = "learningsteps-evo-sub-net"
}

variable "az_priv_dns" {
  description = "Name of the private DNS Zone"
  type        = string
  default     = "learningsteps-evo.postgres.database.azure.com"
}

variable "az_priv_dns_vnet_link" {
  description = "Name of the private DNS Zone VNET link"
  type        = string
  default     = "learningsteps-evo-priv-dns-vnet-link"
}

variable "az_aks_cluster" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "learningsteps-evo-akcc"
}

variable "az_postgresql_server" {
  description = "Name of the DB"
  type        = string
  default     = "learningsteps-evo-postgresql"
}

variable "az_postgresql_user" {
  description = "Name of the DB admin user"
  type        = string
  default     = "evo_ls_psql"
}

variable "az_kv" {
  description = "Name of the Azure Key Vault"
  type        = string
  default     = "learningsteps-evo-kv"
}

variable "az_kv_cert" {
  description = "Name of the Azure Key Vault SSH Certification"
  type        = string
  default     = "learningsteps-evo-kv-cert"
}

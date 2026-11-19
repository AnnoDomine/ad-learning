# ==============================================================================
# Terraform Outputs – Consumed by CI/CD Pipelines and Local Operations
# ==============================================================================

output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = azurerm_resource_group.learningsteps_evo.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.learningsteps_aks_cluster.name
}

output "aks_login_command" {
  description = "Azure CLI command to merge AKS cluster credentials into kubeconfig"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.learningsteps_evo.name} --name ${azurerm_kubernetes_cluster.learningsteps_aks_cluster.name} --overwrite-existing"
}

output "database_fqdn" {
  description = "Private Fully Qualified Domain Name of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.learningsteps_db.fqdn
}

output "key_vault_uri" {
  description = "Vault URI of the Azure Key Vault"
  value       = azurerm_key_vault.learningsteps_evo_key_vault.vault_uri
}

output "acr_login_server" {
  description = "Login server FQDN of the Azure Container Registry"
  value       = azurerm_container_registry.learningsteps_acr.login_server
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.learningsteps_acr.name
}

output "aks_kv_identity_client_id" {
  description = "Client ID of the AKS Key Vault Secrets Store CSI Driver managed identity"
  value       = azurerm_kubernetes_cluster.learningsteps_aks_cluster.key_vault_secrets_provider[0].secret_identity[0].client_id
}

output "key_vault_name" {
  description = "Name of the Azure Key Vault"
  value       = var.az_kv
}

# Note: GitHub Actions masks/strips job outputs matching repository secrets (such as
# AZURE_TENANT_ID), so `deploy.yml` reads `secrets.AZURE_TENANT_ID` directly while
# retaining this output for local `terraform output` inspection.
output "tenant_id" {
  description = "Microsoft Entra ID Tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

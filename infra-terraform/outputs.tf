output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = azurerm_resource_group.learningsteps_evo.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.learningsteps_aks_cluster.name
}

output "aks_login_command" {
  description = "Command to connect kubectl to the AKS cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.learningsteps_evo.name} --name ${azurerm_kubernetes_cluster.learningsteps_aks_cluster.name} --overwrite-existing"
}

output "database_fqdn" {
  description = "Fully Qualified Domain Name of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.learningsteps_db.fqdn
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault"
  value       = azurerm_key_vault.learningsteps_evo_key_vault.vault_uri
}

output "acr_login_server" {
  description = "Azure Container Registry login server"
  value       = azurerm_container_registry.learningsteps_acr.login_server
}

output "acr_name" {
  description = "Azure Container Registry name"
  value       = azurerm_container_registry.learningsteps_acr.name
}

output "aks_kv_identity_client_id" {
  description = "Key-Vault client ID"
  value       = azurerm_kubernetes_cluster.learningsteps_aks_cluster.key_vault_secrets_provider[0].secret_identity[0].client_id
}

output "key_vault_name" {
  description = "Azure Key Vault Name"
  value       = var.az_kv
}

output "tenant_id" {
  description = "Tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

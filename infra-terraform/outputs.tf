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

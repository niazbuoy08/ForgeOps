output "resource_group_name" {
  value = module.resource_group.name
}

output "aks_cluster_name" {
  value = module.aks.name
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "key_vault_name" {
  value = module.key_vault.name
}

output "key_vault_uri" {
  value = module.key_vault.uri
}

output "workload_identity_client_id" {
  description = "Set as azure.workload.identity/client-id on Kubernetes ServiceAccounts and as userAssignedIdentityID in SecretProviderClass resources"
  value       = module.identity.workload_identity_client_id
}

output "get_credentials_command" {
  value = "az aks get-credentials --resource-group ${module.resource_group.name} --name ${module.aks.name} --overwrite-existing"
}

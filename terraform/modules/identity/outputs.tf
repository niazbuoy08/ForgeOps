output "control_plane_identity_id" {
  value = azurerm_user_assigned_identity.control_plane.id
}

output "control_plane_principal_id" {
  value = azurerm_user_assigned_identity.control_plane.principal_id
}

output "kubelet_identity_id" {
  value = azurerm_user_assigned_identity.kubelet.id
}

output "kubelet_principal_id" {
  value = azurerm_user_assigned_identity.kubelet.principal_id
}

output "kubelet_client_id" {
  value = azurerm_user_assigned_identity.kubelet.client_id
}

output "workload_identity_id" {
  value = azurerm_user_assigned_identity.workload.id
}

output "workload_identity_client_id" {
  value = azurerm_user_assigned_identity.workload.client_id
}

output "workload_identity_principal_id" {
  value = azurerm_user_assigned_identity.workload.principal_id
}

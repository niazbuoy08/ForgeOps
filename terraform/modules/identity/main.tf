# User-assigned identity for the AKS control plane (cluster API operations:
# managing the load balancer, route tables, disks in the node resource group).
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${var.prefix}-aks-control-plane"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# User-assigned kubelet identity - what nodes use to pull images from ACR.
resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "id-${var.prefix}-aks-kubelet"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# User-assigned identity federated with Kubernetes service accounts via
# Azure AD Workload Identity, used by application pods (backend, postgres)
# to authenticate to Key Vault through the Secrets Store CSI Driver - no
# secrets or service principal credentials involved.
resource "azurerm_user_assigned_identity" "workload" {
  name                = "id-${var.prefix}-workload"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Federated credentials (binding this identity to specific Kubernetes service
# accounts via the AKS OIDC issuer) are created in the root module, once the
# AKS cluster's OIDC issuer URL is known - see the root main.tf for details.

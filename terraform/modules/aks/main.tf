resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  private_cluster_enabled = var.private_cluster_enabled

  # Azure AD Workload Identity + the OIDC issuer let pods (backend, postgres)
  # authenticate to Azure services (Key Vault) using federated tokens -
  # no stored secrets, no service principal credentials in the cluster.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                 = "system"
    vm_size              = var.node_vm_size
    vnet_subnet_id       = var.vnet_subnet_id
    auto_scaling_enabled = true
    min_count            = var.node_count_min
    max_count            = var.node_count_max
    os_disk_size_gb      = 64
    tags                 = var.tags
  }

  # Cluster (control plane) identity - manages the load balancer, disks,
  # route tables in the node resource group.
  identity {
    type         = "UserAssigned"
    identity_ids = [var.control_plane_identity_id]
  }

  # Kubelet identity - what the nodes themselves use, notably to pull
  # images from ACR via the AcrPull role assignment granted in the acr module.
  kubelet_identity {
    client_id                 = var.kubelet_identity_client_id
    object_id                 = var.kubelet_identity_object_id
    user_assigned_identity_id = var.kubelet_identity_id
  }

  # AKS-managed Azure Key Vault provider for Secrets Store CSI Driver.
  # Installs the CSI driver + azure provider as a managed add-on; pods then
  # authenticate to Key Vault using Workload Identity via SecretProviderClass.
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = var.network_policy
    load_balancer_sku   = "standard"
  }

  azure_policy_enabled = true

  tags = var.tags

  lifecycle {
    ignore_changes = [kubernetes_version]
  }
}

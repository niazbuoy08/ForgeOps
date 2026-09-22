module "resource_group" {
  source   = "../../modules/resource_group"
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "network" {
  source              = "../../modules/network"
  resource_group_name = module.resource_group.name
  location            = var.location
  hub_vnet_name       = "vnet-hub-${var.environment}"
  spoke_vnet_name     = "vnet-spoke-${var.environment}"
  hub_address_space   = ["10.0.0.0/16"]
  spoke_address_space = ["10.1.0.0/16"]
  aks_subnet_prefix   = ["10.1.0.0/22"]
  tags                = var.tags
}

module "identity" {
  source              = "../../modules/identity"
  resource_group_name = module.resource_group.name
  location            = var.location
  prefix              = "aksplat-${var.environment}"
  tags                = var.tags
}

module "aks" {
  source                     = "../../modules/aks"
  name                       = "aks-aksplat-${var.environment}"
  resource_group_name        = module.resource_group.name
  location                   = var.location
  dns_prefix                 = var.aks_dns_prefix
  sku_tier                   = var.aks_sku_tier
  vnet_subnet_id             = module.network.aks_subnet_id
  node_vm_size               = var.node_vm_size
  node_count_min             = var.node_count_min
  node_count_max             = var.node_count_max
  control_plane_identity_id  = module.identity.control_plane_identity_id
  kubelet_identity_id        = module.identity.kubelet_identity_id
  kubelet_identity_client_id = module.identity.kubelet_client_id
  kubelet_identity_object_id = module.identity.kubelet_principal_id
  tags                       = var.tags
}

module "acr" {
  source                        = "../../modules/acr"
  name                          = var.acr_name
  resource_group_name           = module.resource_group.name
  location                      = var.location
  kubelet_identity_principal_id = module.identity.kubelet_principal_id
  tags                          = var.tags
}

module "key_vault" {
  source                         = "../../modules/key_vault"
  name                           = var.key_vault_name
  resource_group_name            = module.resource_group.name
  location                       = var.location
  tenant_id                      = data.azurerm_client_config.current.tenant_id
  workload_identity_principal_id = module.identity.workload_identity_principal_id
  terraform_operator_object_id   = data.azurerm_client_config.current.object_id
  db_username                    = var.db_username
  db_name                        = var.db_name
  tags                           = var.tags
}

# Bind the workload identity to every (namespace, service account) pair that
# needs to read secrets from Key Vault. Requires the AKS OIDC issuer, so this
# is created after the cluster - see terraform/modules/identity for why the
# federated credential lives here instead of inside that module.
locals {
  workload_identity_subjects = toset([
    for pair in setproduct(var.workload_identity_namespaces, var.workload_identity_service_accounts) :
    "${pair[0]}:${pair[1]}"
  ])
}

resource "azurerm_federated_identity_credential" "workload" {
  for_each = local.workload_identity_subjects

  name                = "fed-${replace(each.value, ":", "-")}"
  resource_group_name = module.resource_group.name
  parent_id           = module.identity.workload_identity_id
  issuer              = module.aks.oidc_issuer_url
  subject             = "system:serviceaccount:${split(":", each.value)[0]}:${split(":", each.value)[1]}"
  audience            = ["api://AzureADTokenExchange"]
}

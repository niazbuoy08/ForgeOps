resource "azurerm_key_vault" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  tenant_id                     = var.tenant_id
  sku_name                      = var.sku_name
  rbac_authorization_enabled    = true
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  public_network_access_enabled = true
  tags                          = var.tags
}

# Terraform's own identity needs write access to manage secrets.
resource "azurerm_role_assignment" "operator_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.terraform_operator_object_id
}

# The AKS workload identity (used by backend/postgres pods via the Secrets
# Store CSI Driver) only needs read access to secrets.
resource "azurerm_role_assignment" "workload_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.workload_identity_principal_id
}

# Generate a strong database password. This value only ever lives in Azure
# Key Vault and Terraform state (which must be stored in the encrypted
# remote backend, never committed to Git).
resource "random_password" "db_password" {
  length      = 32
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
}

resource "azurerm_key_vault_secret" "db_username" {
  name         = "db-username"
  value        = var.db_username
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [azurerm_role_assignment.operator_secrets_officer]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [azurerm_role_assignment.operator_secrets_officer]
}

resource "azurerm_key_vault_secret" "db_host" {
  name = "db-host"
  # Matches the postgres Helm chart's Service name (kubernetes/helm/postgres,
  # fullnameOverride unset -> "postgres"). Backend and postgres pods always
  # run in the same namespace, so the short in-cluster DNS name resolves
  # without needing the namespace or a full FQDN.
  value        = "postgres"
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [azurerm_role_assignment.operator_secrets_officer]
}

resource "azurerm_key_vault_secret" "db_name" {
  name         = "db-name"
  value        = var.db_name
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [azurerm_role_assignment.operator_secrets_officer]
}

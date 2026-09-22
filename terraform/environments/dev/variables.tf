variable "environment" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "resource_group_name" {
  type    = string
  default = "rg-aks-platform-dev"
}

variable "acr_name" {
  description = "Globally unique ACR name (alphanumeric only, 5-50 chars)"
  type        = string
}

variable "key_vault_name" {
  description = "Globally unique Key Vault name"
  type        = string
}

variable "aks_dns_prefix" {
  type    = string
  default = "aksplat-dev"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "node_count_min" {
  type    = number
  default = 1
}

variable "node_count_max" {
  type    = number
  default = 3
}

variable "aks_sku_tier" {
  type    = string
  default = "Free"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

# Kubernetes namespaces (and the service account name each app uses in that
# namespace) allowed to federate as the workload identity to reach Key Vault.
# The dev cluster hosts all three environment namespaces by default to keep
# this a single, cost-efficient AKS cluster for the portfolio demo - see
# docs/architecture.md for the multi-cluster alternative.
variable "workload_identity_namespaces" {
  type    = list(string)
  default = ["dev", "staging", "prod"]
}

variable "workload_identity_service_accounts" {
  type    = list(string)
  default = ["backend", "postgres"]
}

variable "tags" {
  type = map(string)
  default = {
    project     = "aks-gitops-platform"
    environment = "dev"
    managedBy   = "terraform"
  }
}

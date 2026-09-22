variable "environment" {
  type    = string
  default = "staging"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "resource_group_name" {
  type    = string
  default = "rg-aks-platform-staging"
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
  default = "aksplat-staging"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "node_count_min" {
  type    = number
  default = 2
}

variable "node_count_max" {
  type    = number
  default = 5
}

variable "aks_sku_tier" {
  type    = string
  default = "Standard"
}

variable "db_username" {
  type    = string
  default = "appuser"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "workload_identity_namespaces" {
  description = "Only relevant if this environment gets its own dedicated cluster - see dev's variables.tf for the shared-cluster default."
  type        = list(string)
  default     = ["staging"]
}

variable "workload_identity_service_accounts" {
  type    = list(string)
  default = ["backend", "postgres"]
}

variable "tags" {
  type = map(string)
  default = {
    project     = "aks-gitops-platform"
    environment = "staging"
    managedBy   = "terraform"
  }
}

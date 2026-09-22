variable "name" {
  description = "Globally unique Key Vault name"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "standard"
}

variable "workload_identity_principal_id" {
  description = "Principal ID of the workload identity (backend/postgres pods) - granted Key Vault Secrets User"
  type        = string
}

variable "terraform_operator_object_id" {
  description = "Object ID of the identity running Terraform (user or service principal) - granted Key Vault Secrets Officer so this module can write secrets"
  type        = string
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  description = "Database username stored in Key Vault. Not a real production password - rotate after first apply if desired."
  type        = string
  default     = "appuser"
}

variable "purge_protection_enabled" {
  type    = bool
  default = false
}

variable "soft_delete_retention_days" {
  type    = number
  default = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}

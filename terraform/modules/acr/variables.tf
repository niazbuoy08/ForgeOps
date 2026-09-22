variable "name" {
  description = "Globally unique ACR name (alphanumeric only)"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku" {
  type    = string
  default = "Standard"
}

variable "admin_enabled" {
  description = "Whether the ACR admin account is enabled. Kept false - AKS pulls images via managed identity, not shared admin credentials."
  type        = bool
  default     = false
}

variable "kubelet_identity_principal_id" {
  description = "Principal ID of the AKS kubelet managed identity to grant AcrPull"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

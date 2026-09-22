variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "dns_prefix" {
  type = string
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version. Leave null to use the current AKS default."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "Free or Standard (Standard gives an SLA-backed control plane, recommended for staging/prod)"
  type        = string
  default     = "Free"
}

variable "vnet_subnet_id" {
  type = string
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

variable "control_plane_identity_id" {
  description = "User-assigned identity ID used by the AKS control plane"
  type        = string
}

variable "kubelet_identity_id" {
  type = string
}

variable "kubelet_identity_client_id" {
  type = string
}

variable "kubelet_identity_object_id" {
  type = string
}

variable "private_cluster_enabled" {
  description = "Whether the AKS API server has only a private endpoint. False by default to keep kubectl access simple for a portfolio demo; set true for a stricter production posture."
  type        = bool
  default     = false
}

variable "network_policy" {
  type    = string
  default = "azure"
}

variable "tags" {
  type    = map(string)
  default = {}
}

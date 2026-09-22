variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "hub_vnet_name" {
  type    = string
  default = "vnet-hub"
}

variable "hub_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "hub_shared_subnet_prefix" {
  description = "Subnet reserved for shared hub connectivity resources (e.g. a future VPN/Bastion/firewall)"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "spoke_vnet_name" {
  type    = string
  default = "vnet-spoke"
}

variable "spoke_address_space" {
  type    = list(string)
  default = ["10.1.0.0/16"]
}

variable "aks_subnet_prefix" {
  description = "Subnet used by AKS nodes"
  type        = list(string)
  default     = ["10.1.0.0/22"]
}

variable "tags" {
  type    = map(string)
  default = {}
}

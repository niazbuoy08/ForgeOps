variable "name" {
  description = "Globally unique storage account name (lowercase alphanumeric, 3-24 chars)"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "container_name" {
  type    = string
  default = "tfstate"
}

variable "account_tier" {
  type    = string
  default = "Standard"
}

variable "account_replication_type" {
  type    = string
  default = "LRS"
}

variable "tags" {
  type    = map(string)
  default = {}
}

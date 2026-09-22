variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "prefix" {
  description = "Naming prefix, e.g. aksplat-dev"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

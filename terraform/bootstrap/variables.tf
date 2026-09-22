variable "resource_group_name" {
  description = "Resource group that will hold the Terraform remote state storage account"
  type        = string
  default     = "rg-aks-platform-tfstate"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "storage_account_name" {
  description = "Globally unique name (lowercase alphanumeric, 3-24 chars), e.g. sttfstateaksplat001"
  type        = string
}

variable "tags" {
  type = map(string)
  default = {
    project   = "aks-gitops-platform"
    purpose   = "terraform-remote-state"
    managedBy = "terraform"
  }
}

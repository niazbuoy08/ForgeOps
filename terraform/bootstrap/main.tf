# One-time bootstrap: creates the resource group + storage account that
# every environment's Terraform remote state backend points at.
#
# This configuration intentionally uses LOCAL state (no backend block) -
# there is no remote backend to store its own state in yet. Run it once,
# then never modify the resulting storage account's name; every environment
# references it by name in their backend-config.
#
# See docs/deployment.md for the full bootstrap walkthrough.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "state_resource_group" {
  source   = "../modules/resource_group"
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "state_storage" {
  source                   = "../modules/storage"
  name                     = var.storage_account_name
  resource_group_name      = module.state_resource_group.name
  location                 = var.location
  container_name           = "tfstate"
  account_replication_type = "LRS"
  tags                     = var.tags
}

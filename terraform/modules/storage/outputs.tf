output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "container_name" {
  value = azurerm_storage_container.tfstate.name
}

output "id" {
  value = azurerm_storage_account.this.id
}

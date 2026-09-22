output "resource_group_name" {
  value = module.state_resource_group.name
}

output "storage_account_name" {
  value = module.state_storage.storage_account_name
}

output "container_name" {
  value = module.state_storage.container_name
}

output "resource_group_name" {
  description = "Nome do resource group usado pela infraestrutura principal."
  value       = data.azurerm_resource_group.main.name
}

output "virtual_network_name" {
  description = "Nome da virtual network criada."
  value       = azurerm_virtual_network.main.name
}

output "virtual_network_id" {
  description = "ID da virtual network criada."
  value       = azurerm_virtual_network.main.id
}

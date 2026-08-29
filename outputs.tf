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

output "subnet_name" {
  description = "Nome da subnet criada."
  value       = azurerm_subnet.main.name
}

output "subnet_id" {
  description = "ID da subnet criada."
  value       = azurerm_subnet.main.id
}

output "acr_login_server" {
  description = "Login server do Azure Container Registry, usado no docker tag/push/pull."
  value       = azurerm_container_registry.main.login_server
}

output "acr_name" {
  description = "Nome do Azure Container Registry criado."
  value       = azurerm_container_registry.main.name
}

output "aci_fqdn" {
  description = "URL publica do Azure Container Instance."
  value       = "http://${azurerm_container_group.main.fqdn}"
}

output "aci_ip_address" {
  description = "IP publico do Azure Container Instance."
  value       = azurerm_container_group.main.ip_address
}

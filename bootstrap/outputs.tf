output "resource_group_name" {
  description = "Nome do resource group criado para o projeto."
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Regiao Azure usada pelo resource group."
  value       = azurerm_resource_group.main.location
}

output "storage_account_name" {
  description = "Nome da storage account criada para o backend remoto."
  value       = azurerm_storage_account.tfstate.name
}

output "state_container_name" {
  description = "Nome do container Blob criado para armazenar o tfstate."
  value       = azurerm_storage_container.tfstate.name
}

output "backend_key_example" {
  description = "Exemplo de key para configurar o backend remoto da infraestrutura principal."
  value       = "network/terraform.tfstate"
}

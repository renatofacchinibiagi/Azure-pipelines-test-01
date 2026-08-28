variable "resource_group_name" {
  description = "Nome do resource group que armazenara o backend remoto e a infraestrutura principal."
  type        = string
  default     = "rg-azure-pipelines-test-01"
}

variable "location" {
  description = "Regiao Azure para criar o resource group e a storage account do state."
  type        = string
  default     = "eastus"
}

variable "storage_account_name" {
  description = "Nome opcional da storage account do tfstate. Se vazio, sera gerado com sufixo aleatorio."
  type        = string
  default     = null

  validation {
    condition     = var.storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "O nome da storage account deve ter de 3 a 24 caracteres, usando apenas letras minusculas e numeros."
  }
}

variable "state_container_name" {
  description = "Nome do container Blob usado para armazenar arquivos tfstate."
  type        = string
  default     = "tfstate"
}

variable "tags" {
  description = "Tags aplicadas aos recursos de bootstrap."
  type        = map(string)
  default = {
    project     = "azure-pipelines-test-01"
    environment = "dev"
    managed_by  = "terraform"
    purpose     = "tfstate"
  }
}

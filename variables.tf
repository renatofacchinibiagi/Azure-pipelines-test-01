variable "resource_group_name" {
  description = "Nome do resource group criado pelo bootstrap e usado pela infraestrutura principal."
  type        = string
  default     = "rg-azure-pipelines-test-01"
}

variable "virtual_network_name" {
  description = "Nome da virtual network."
  type        = string
  default     = "vnet-azure-pipelines-test-01"
}

variable "vnet_address_space" {
  description = "Bloco CIDR da virtual network."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "subnet_name" {
  description = "Nome da subnet criada dentro da virtual network."
  type        = string
  default     = "snet-azure-pipelines-test-01"
}

variable "subnet_address_prefixes" {
  description = "Bloco CIDR da subnet. Deve estar dentro do address space da VNet."
  type        = list(string)
  default     = ["10.10.1.0/24"]
}

variable "tags" {
  description = "Tags aplicadas aos recursos da infraestrutura principal."
  type        = map(string)
  default = {
    project     = "azure-pipelines-test-01"
    environment = "dev"
    managed_by  = "terraform"
  }
}

variable "acr_name" {
  description = "Nome do Azure Container Registry. Deve ser globalmente unico, apenas letras minusculas e numeros. Se nao informado, um sufixo aleatorio e adicionado."
  type        = string
  default     = null

  validation {
    condition     = var.acr_name == null || can(regex("^[a-z0-9]{5,50}$", var.acr_name))
    error_message = "O nome do ACR deve ter de 5 a 50 caracteres, usando apenas letras minusculas e numeros."
  }
}

variable "acr_sku" {
  description = "SKU do Azure Container Registry. Basic e a opcao mais barata para lab."
  type        = string
  default     = "Basic"
}

variable "container_image_name" {
  description = "Nome da imagem Docker publicada no ACR."
  type        = string
  default     = "azure-pipelines-test-01"
}

variable "container_image_tag" {
  description = "Tag da imagem Docker publicada no ACR."
  type        = string
  default     = "v2"
}

variable "container_cpu" {
  description = "Quantidade de vCPU alocada para o Azure Container Instance."
  type        = number
  default     = 0.5
}

variable "container_memory_gb" {
  description = "Quantidade de memoria em GB alocada para o Azure Container Instance."
  type        = number
  default     = 1
}

variable "aci_dns_name_label" {
  description = "Prefixo do DNS publico do Azure Container Instance. Deve ser globalmente unico na regiao. Se nao informado, um sufixo aleatorio e adicionado."
  type        = string
  default     = null
}

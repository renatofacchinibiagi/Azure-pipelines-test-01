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

variable "tags" {
  description = "Tags aplicadas aos recursos da infraestrutura principal."
  type        = map(string)
  default = {
    project     = "azure-pipelines-test-01"
    environment = "dev"
    managed_by  = "terraform"
  }
}

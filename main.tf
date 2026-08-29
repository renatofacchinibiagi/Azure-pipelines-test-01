data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "main" {
  name                = var.virtual_network_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "main" {
  name                 = var.subnet_name
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.subnet_address_prefixes
}

resource "random_string" "acr_suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "random_string" "aci_dns_suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false
}

locals {
  acr_name           = coalesce(var.acr_name, "acrazpipe01${random_string.acr_suffix.result}")
  aci_dns_name_label = coalesce(var.aci_dns_name_label, "azpipe01-${random_string.aci_dns_suffix.result}")
  container_image    = "${azurerm_container_registry.main.login_server}/${var.container_image_name}:${var.container_image_tag}"
}

# Registro de imagens Docker. Admin user fica desabilitado; o pull usa managed identity.
resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = var.acr_sku
  admin_enabled       = false
  tags                = var.tags
}

# Identidade dedicada para o Container Instance puxar a imagem do ACR sem senha.
resource "azurerm_user_assigned_identity" "aci" {
  name                = "id-aci-azure-pipelines-test-01"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "aci_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aci.principal_id
}

# Container publico simples para o lab. Exclua o resource group ou este recurso ao terminar de testar.
resource "azurerm_container_group" "main" {
  name                = "aci-azure-pipelines-test-01"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  os_type             = "Linux"
  ip_address_type     = "Public"
  dns_name_label      = local.aci_dns_name_label
  tags                = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aci.id]
  }

  image_registry_credential {
    server                    = azurerm_container_registry.main.login_server
    user_assigned_identity_id = azurerm_user_assigned_identity.aci.id
  }

  container {
    name   = "web"
    image  = local.container_image
    cpu    = var.container_cpu
    memory = var.container_memory_gb

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  depends_on = [azurerm_role_assignment.aci_acr_pull]
}

# Terraform definitions of WWT's web frontend: the App Gateway, CDN setup, etc.

resource "azurerm_resource_group" "web_frontend_legacy" {
  name     = var.legacyNameFrontendGroup
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

# The App Gateway and supporting resources

resource "azurerm_public_ip" "frontend" {
  name                = "wwtappgw1-pip1"
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = azurerm_resource_group.web_frontend_legacy.location
  sku                 = "Standard"
  allocation_method   = "Static"

  lifecycle {
    prevent_destroy = true
  }
}

#resource "azurerm_application_gateway" "frontend" {
#  name                = "wwtappgw1"
#  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
#  location            = azurerm_resource_group.web_frontend_legacy.location
#
#  backend_address_pool {}
#  backend_http_settings {}
#  frontend_ip_configuration {
#    name                 = local.frontend_ip_configuration_name
#    public_ip_address_id = azurerm_public_ip.example.id
#  }
#  frontend_port {}
#  gateway_ip_configuration {}
#  http_listener {}
#  request_routing_rule {}
#  sku {}
#  lifecycle {
#    prevent_destroy = true
#  }
#}

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

resource "azurerm_virtual_network" "frontend" {
  name                = "wwtbackend-rm-vnet"
  location            = azurerm_resource_group.web_frontend_legacy.location
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  address_space       = ["192.168.0.0/16"]

  subnet {
    name           = "subnet-1"
    address_prefix = "192.168.1.0/24"
  }

  subnet {
    name           = "GatewaySubnet"
    address_prefix = "192.168.0.0/24"
  }

  lifecycle {
    prevent_destroy = true
  }
}

#resource "azurerm_application_gateway" "frontend" {
#  name                = "wwtappgw1"
#  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
#  location            = azurerm_resource_group.web_frontend_legacy.location
#
#  frontend_ip_configuration {
#    name                 = "appGwPublicFrontendIp"
#    public_ip_address_id = azurerm_public_ip.frontend.id
#  }
#
#  frontend_port {
#    name = "port_80"
#    port = 80
#  }
#
#  frontend_port {
#    name = "port_443"
#    port = 443
#  }
#
#  gateway_ip_configuration {
#    name = "appGatewayIpConfig"
#    subnet_id =
#  }
#
#  backend_address_pool {}
#  backend_http_settings {}
#  frontend_port {}
#  gateway_ip_configuration {}
#  http_listener {}
#  request_routing_rule {}
#  sku {}
#  lifecycle {
#    prevent_destroy = true
#  }
#}

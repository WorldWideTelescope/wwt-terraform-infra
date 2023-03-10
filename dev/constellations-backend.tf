# The backend database and API service for the Constellations web app.

resource "azurerm_resource_group" "cx_backend" {
  name     = "${var.prefix}-cxbackend"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

# App service plan

resource "azurerm_service_plan" "cx_backend" {
  name                = "ASP-${var.prefix}cxbackend-ba6b"  # XXX aligning with autocreated
  resource_group_name = azurerm_resource_group.cx_backend.name
  location            = azurerm_resource_group.cx_backend.location
  os_type             = "Linux"
  sku_name            = "P1v2"
}

# Virtual Network for web app to talk to database

resource "azurerm_virtual_network" "cx_backend" {
  name                = "${var.prefix}-cxbeVnet"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "cx_backend_main" {
  name                 = "${var.prefix}-cxbeSubnet"
  resource_group_name  = azurerm_resource_group.cx_backend.name
  virtual_network_name = azurerm_virtual_network.cx_backend.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "cx_backend_app" {
  name                 = "${var.prefix}-cxbeAppSubnet"
  resource_group_name  = azurerm_resource_group.cx_backend.name
  virtual_network_name = azurerm_virtual_network.cx_backend.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "dlg-appServices"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

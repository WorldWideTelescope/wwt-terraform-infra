# The backend database and API service for the Constellations web app.

resource "azurerm_resource_group" "cx_backend" {
  name     = "${var.prefix}-cxbackend"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

# The CosmosDB/MongoDB server

resource "azurerm_cosmosdb_account" "cx_backend" {
  name                = "${var.prefix}-cxbe-server"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  geo_location {
    location          = azurerm_resource_group.cx_backend.location
    failover_priority = 0
  }

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  tags = {
    # These might not be important, but were auto-assigned when I created this
    # resource with Microsoft's template.
    defaultExperience       = "Azure Cosmos DB for MongoDB API"
    hidden-cosmos-mmspecial = ""
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

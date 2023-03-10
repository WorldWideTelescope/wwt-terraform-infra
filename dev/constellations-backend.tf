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

# The app

resource "azurerm_linux_web_app" "cx_backend" {
  name                = "${var.prefix}-cxbe"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  service_plan_id     = azurerm_service_plan.cx_backend.id

  app_settings = {
    "AZURE_COSMOS_CONNECTIONSTRING" = azurerm_cosmosdb_account.cx_backend.connection_strings[0]
  }

  site_config {
    always_on = false
    ftps_state = "FtpsOnly"
    vnet_route_all_enabled = true
  }

  virtual_network_subnet_id = azurerm_subnet.cx_backend_app.id
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

resource "azurerm_private_endpoint" "cx_backend" {
  name                = "${var.prefix}-cxbeDbEndpoint"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  subnet_id           = azurerm_subnet.cx_backend_main.id

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.cx_backend.id]
  }

  private_service_connection {
    name                           = "${var.prefix}-cxbeDbEndpoint"
    private_connection_resource_id = replace(azurerm_cosmosdb_account.cx_backend.id, "DocumentDB", "DocumentDb")
    is_manual_connection = false
    subresource_names = ["MongoDB"]
  }
}

# Private DNS Zone for the app and the DB to talk

resource "azurerm_private_dns_zone" "cx_backend" {
  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = azurerm_resource_group.cx_backend.name
}

resource "azurerm_private_dns_a_record" "cx_backend_server" {
  name                = "${var.prefix}-cxbe-server"
  zone_name           = azurerm_private_dns_zone.cx_backend.name
  resource_group_name = azurerm_resource_group.cx_backend.name
  ttl                 = 10
  records             = ["10.0.0.4"]

  tags = {
    # More inherited tags that presumably don't matter
    creator = "created by private endpoint wwtdev-cxbeDbEndpoint with resource guid 00435c8a-487f-4301-810d-ed3ce8ab0fdf"
  }
}

resource "azurerm_private_dns_a_record" "cx_backend_server_loc" {
  name                = "${var.prefix}-cxbe-server-${azurerm_resource_group.cx_backend.location}"
  zone_name           = azurerm_private_dns_zone.cx_backend.name
  resource_group_name = azurerm_resource_group.cx_backend.name
  ttl                 = 10
  records             = ["10.0.0.5"]

  tags = {
    # More inherited tags that presumably don't matter
    creator = "created by private endpoint wwtdev-cxbeDbEndpoint with resource guid 00435c8a-487f-4301-810d-ed3ce8ab0fdf"
  }
}

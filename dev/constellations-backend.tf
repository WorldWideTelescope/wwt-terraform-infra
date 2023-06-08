# The backend database and API service for the Constellations web app.
#
# Because the MongoDB is isolated on a private network, the usual Azure admin
# systems do not work. However, with the bastion host setup defined in
# `constellations-bastion.tf`, it is possible to administer the database
# locally.
#
# 1. First, set up the bastion and SSH into it.
# 2. Forward a port to the DB:
# ```
# ssh -O forward -L 10255:wwtdev-cxbe-server.mongo.cosmos.azure.com:10255 wwt@wwtdevcxb.westus.cloudapp.azure.com
# ```
# 3. Make a temporary connection string, replacing the `...cosmos.azure.com` hostname
#    with `localhost`. You can get the connection string from the database's admin
#    page in the Azure Portal.
# 4. Connect using pymongo with some special settings:
# ```
# conn = pymongo.MongoClient(cs, tlsAllowInvalidCertificates=True, directConnection=True)
# ```
#     where `cs` is the temporary connection string.

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
    "CX_PREVIEW_BASE_URL"           = "https://${azurerm_cdn_endpoint_custom_domain.cxdata.host_name}/previews"
    "CX_PREVIEW_SERVICE_URL"        = "http://${azurerm_private_dns_a_record.cx_previewer_server.name}.azurewebsites.net"
    "CX_SESSION_SECRETS"            = var.sessionSecrets
    "CX_SUPERUSER_ACCOUNT_ID"       = var.superuserAccountId
    "KEYCLOAK_URL"                  = "https://${var.tld}/auth/"
  }

  site_config {
    always_on              = false
    ftps_state             = "FtpsOnly"
    vnet_route_all_enabled = true
    app_command_line       = "yarn start"
  }

  logs {
    detailed_error_messages = false
    failed_request_tracing  = false

    http_logs {
      file_system {
        retention_in_days = 0
        retention_in_mb   = 35
      }
    }
  }

  virtual_network_subnet_id = azurerm_subnet.cx_backend_app.id
}

# Public custom hostname for the backend app

resource "azurerm_dns_cname_record" "api" {
  name                = "api"
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name # must be same as the zone
  zone_name           = azurerm_dns_zone.flagship.name
  ttl                 = 3600
  record              = "${azurerm_linux_web_app.cx_backend.default_hostname}."
}

resource "azurerm_app_service_custom_hostname_binding" "cx_backend" {
  hostname            = "api.${var.tld}"
  resource_group_name = azurerm_resource_group.cx_backend.name
  app_service_name    = azurerm_linux_web_app.cx_backend.name

  # These are managed through the cert binding:
  lifecycle {
    ignore_changes = [ssl_state, thumbprint]
  }
}

resource "azurerm_app_service_managed_certificate" "cx_backend" {
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.cx_backend.id
}

resource "azurerm_app_service_certificate_binding" "cx_backend" {
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.cx_backend.id
  certificate_id      = azurerm_app_service_managed_certificate.cx_backend.id
  ssl_state           = "SniEnabled"
}

# App service plan

resource "azurerm_service_plan" "cx_backend" {
  name                = "ASP-${var.prefix}cxbackend-ba6b" # XXX aligning with autocreated
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
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.cx_backend.id]
  }

  private_service_connection {
    name                           = "${var.prefix}-cxbeDbEndpoint"
    private_connection_resource_id = replace(azurerm_cosmosdb_account.cx_backend.id, "DocumentDB", "DocumentDb")
    is_manual_connection           = false
    subresource_names              = ["MongoDB"]
  }
}

# Private DNS Zone for the app and the DB to talk

resource "azurerm_private_dns_zone" "cx_backend" {
  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = azurerm_resource_group.cx_backend.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "cx_backend" {
  name                  = "privatelink.mongo.cosmos.azure.com-dblink"
  resource_group_name   = azurerm_resource_group.cx_backend.name
  private_dns_zone_name = azurerm_private_dns_zone.cx_backend.name
  virtual_network_id    = azurerm_virtual_network.cx_backend.id
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

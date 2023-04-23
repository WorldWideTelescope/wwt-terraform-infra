# The previewer microservice for the Constellations web app.
#
# For now (?) we are piggybacking on the app service plan for the main backend
# app, and the vnet subnet for the Mongo DB.

resource "azurerm_linux_web_app" "cx_previewer" {
  name                = "${var.prefix}-cxpv"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  service_plan_id     = azurerm_service_plan.cx_backend.id

  app_settings = {
    "AZURE_COSMOS_CONNECTIONSTRING"   = azurerm_cosmosdb_account.cx_backend.connection_strings[0]
    "AZURE_STORAGE_CONNECTION_STRING" = azurerm_storage_account.constellations.primary_connection_string
    "NUXT_PUBLIC_API_URL"             = "https://api.${var.tld}"
    "DOCKER_REGISTRY_SERVER_URL"      = "https://index.docker.io/v1"
  }

  site_config {
    always_on              = false
    ftps_state             = "FtpsOnly"
    vnet_route_all_enabled = true
    app_command_line       = "node server/dist/server.js"

    application_stack {
      docker_image     = "aasworldwidetelescope/constellations-previewer"
      docker_image_tag = "latest"
    }
  }
}

resource "azurerm_private_endpoint" "cx_previewer" {
  name                = "${var.prefix}-cxpvEndpoint"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  subnet_id           = azurerm_subnet.cx_backend_main.id

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.cx_previewer.id]
  }

  private_service_connection {
    name                           = "${var.prefix}-cxpvEndpoint-ad9f" # syncs with manual creation
    private_connection_resource_id = azurerm_linux_web_app.cx_previewer.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }
}

resource "azurerm_private_dns_zone" "cx_previewer" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.cx_backend.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "cx_previewer" {
  name                  = "4cf0ae2c205e4" # matching manual creation
  resource_group_name   = azurerm_resource_group.cx_backend.name
  private_dns_zone_name = azurerm_private_dns_zone.cx_previewer.name
  virtual_network_id    = azurerm_virtual_network.cx_backend.id
}

resource "azurerm_private_dns_a_record" "cx_previewer_server" {
  name                = "${var.prefix}-cxpv"
  zone_name           = azurerm_private_dns_zone.cx_previewer.name
  resource_group_name = azurerm_resource_group.cx_backend.name
  ttl                 = 10
  records             = ["10.0.0.6"]

  tags = {
    "creator" = "created by private endpoint wwtdev-cxpvEndpoint with resource guid 6af9f47a-2a22-43b5-9ecb-6c7525a28895"
  }
}

resource "azurerm_private_dns_a_record" "cx_previewer_server_scm" {
  name                = "${var.prefix}-cxpv.scm"
  zone_name           = azurerm_private_dns_zone.cx_previewer.name
  resource_group_name = azurerm_resource_group.cx_backend.name
  ttl                 = 10
  records             = ["10.0.0.6"]

  tags = {
    "creator" = "created by private endpoint wwtdev-cxpvEndpoint with resource guid 6af9f47a-2a22-43b5-9ecb-6c7525a28895"
  }
}

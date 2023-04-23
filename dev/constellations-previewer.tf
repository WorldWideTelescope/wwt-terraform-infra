# The previewer microservice for the Constellations web app.
#
# The setup is complicated, perhaps more complicated than it needs to be. The
# fundamental issue is that we want this web app to not be publicly available;
# it should only be accessible from our VPN.
#
# - To make that be the case, we need to associate it with a "private endpoint"
# - But, it seems that in order for it to be able to communicate with the
#   MongoDB, the app also needs to be assigned to a "delegated" vnet subnet.
# - Azure "app service plans" have a limit of two vnets associations per
#   service, and the backend/keycloak plan has one for each of those. So this
#   needs to be on its own plan.
# - Private endpoints are associated with subnets, but can't be associated with
#   delegated subnets. So the app lives on two different subnets.
#
# That last piece makes me feel like I'm doing something wrong, but I haven't
# been able to figure out a better setup.
#
# Because the app only provides a private endpoint, much of the standard Azure
# tooling does not work, or does not work conveniently. As far as I can tell, to
# do much of anything we need to set up a bastion host (see
# `constellations-bastion.tf`) and do stuff in the terminal. To look at logs:
#
# ```
# curl 'https://$wwtdev-cxpv:(pwd)@wwtdev-cxpv.scm.azurewebsites.net/api/logs/docker/zip' --output docker.zip
# curl 'https://$wwtdev-cxpv:(pwd)@wwtdev-cxpv.scm.azurewebsites.net/api/logstream'
# ```
#
# Here, you can get the username/password from the deployment center settings of
# webhook URL. Manually trigger Docker update:
#
# ```
# curl -X POST 'https://$wwtdev-cxpv:(pwd)@wwtdev-cxpv.scm.azurewebsites.net/api/registry/webhook'
# ```
#
# etc.

resource "azurerm_linux_web_app" "cx_previewer" {
  name                = "${var.prefix}-cxpv"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  service_plan_id     = azurerm_service_plan.cx_previewer.id

  app_settings = {
    "MONGO_CONNECTION_STRING"         = azurerm_cosmosdb_account.cx_backend.connection_strings[0]
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

  virtual_network_subnet_id = azurerm_subnet.cx_previewer.id

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
}

resource "azurerm_service_plan" "cx_previewer" {
  name                = "${var.prefix}-cxpv"
  resource_group_name = azurerm_resource_group.cx_backend.name
  location            = azurerm_resource_group.cx_backend.location
  os_type             = "Linux"
  sku_name            = "P1v2"
}

resource "azurerm_subnet" "cx_previewer" {
  name                 = "${var.prefix}-cxpv"
  resource_group_name  = azurerm_resource_group.cx_backend.name
  virtual_network_name = azurerm_virtual_network.cx_backend.name
  address_prefixes     = ["10.0.10.0/24"]

  delegation {
    name = "dlg-appServices"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
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
  records             = [azurerm_private_endpoint.cx_previewer.private_service_connection[0].private_ip_address]

  tags = {
    "creator" = "created by private endpoint wwtdev-cxpvEndpoint with resource guid bcaa592e-a1be-48ea-8b79-6e9b121ec461"
  }
}

resource "azurerm_private_dns_a_record" "cx_previewer_server_scm" {
  name                = "${var.prefix}-cxpv.scm"
  zone_name           = azurerm_private_dns_zone.cx_previewer.name
  resource_group_name = azurerm_resource_group.cx_backend.name
  ttl                 = 10
  records             = [azurerm_private_endpoint.cx_previewer.private_service_connection[0].private_ip_address]

  tags = {
    "creator" = "created by private endpoint wwtdev-cxpvEndpoint with resource guid bcaa592e-a1be-48ea-8b79-6e9b121ec461"
  }
}

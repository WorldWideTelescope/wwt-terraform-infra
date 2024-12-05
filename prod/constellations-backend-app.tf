# The Constellations backend app service

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
    always_on              = true
    ftps_state             = "FtpsOnly"
    vnet_route_all_enabled = true
    app_command_line       = "yarn start"

    ip_restriction_default_action     = "Allow"
    scm_ip_restriction_default_action = "Allow"
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

# "stage" slot identical but not always_on. Note that most config/settings
# swap when you swap deployment slots, so this slot and production must
# be kept in sync. Fortunately the always_on setting stays put.
resource "azurerm_linux_web_app_slot" "cx_backend_stage" {
  name           = "stage"
  app_service_id = azurerm_linux_web_app.cx_backend.id

  app_settings = azurerm_linux_web_app.cx_backend.app_settings

  site_config {
    always_on              = false
    ftps_state             = "FtpsOnly"
    vnet_route_all_enabled = true
    app_command_line       = "yarn start"

    ip_restriction_default_action     = "Allow"
    scm_ip_restriction_default_action = "Allow"
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

  virtual_network_subnet_id = azurerm_linux_web_app.cx_backend.virtual_network_subnet_id
}

# Public custom hostname for the backend app

resource "azurerm_dns_cname_record" "api" {
  name                = "api"
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
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

# Let the app talk with the support services

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

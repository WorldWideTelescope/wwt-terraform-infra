# The Keycloak ident/auth service for Constellations

resource "azurerm_linux_web_app" "keycloak" {
  name                = "${var.prefix}-keycloak"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  service_plan_id     = azurerm_service_plan.cx_backend.id

  app_settings = {
    "KC_DB"                   = "postgres"
    "KC_DB_URL"               = "jdbc:postgresql://${azurerm_private_dns_a_record.cx_backend_sql.fqdn}/keycloak?sslmode=prefer&sslrootcert=/etc/ssl/certs/ca-bundle.crt"
    "KC_DB_USERNAME"          = "psqladmin@${azurerm_private_dns_a_record.cx_backend_sql.name}"
    "KC_DB_PASSWORD"          = var.cxsqlAdminPassword
    "KC_HOSTNAME"             = "${var.tld}"
    "KC_HOSTNAME_ADMIN"       = "${var.tld}"
    "KC_HOSTNAME_STRICT"      = "false"
    "KC_HTTP_RELATIVE_PATH"   = "/auth"
    "KC_PROXY"                = "edge"
    "KEYCLOAK_ADMIN"          = "wwtadmin"
    "KEYCLOAK_ADMIN_PASSWORD" = var.cxkeycloakAdminPassword
  }

  https_only = false

  site_config {
    always_on              = true
    ftps_state             = "Disabled"
    vnet_route_all_enabled = true
    app_command_line       = "start"

    application_stack {
      docker_image_name   = "keycloak/keycloak:22.0"
      docker_registry_url = "https://quay.io"
    }
  }

  virtual_network_subnet_id = azurerm_subnet.cx_backend_keycloak.id
}

resource "azurerm_subnet" "cx_backend_keycloak" {
  name                 = "${var.prefix}-cxbeKcSubnet"
  resource_group_name  = azurerm_resource_group.cx_backend.name
  virtual_network_name = azurerm_virtual_network.cx_backend.name
  address_prefixes     = ["10.0.6.0/24"]

  delegation {
    name = "dlg-appServices"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

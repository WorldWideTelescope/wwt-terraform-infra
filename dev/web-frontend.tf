# Terraform definitions of WWT's web frontend: the App Gateway etc.

resource "azurerm_resource_group" "gateway" {
  name     = "${var.prefix}-gw"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}


# The App Gateway and supporting resources

resource "azurerm_public_ip" "gateway" {
  name                = "${var.prefix}-gw-pip"
  resource_group_name = azurerm_resource_group.gateway.name
  location            = azurerm_resource_group.gateway.location
  sku                 = "Standard"
  allocation_method   = "Static"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_dns_a_record" "cx_root_a" {
  name                = "@"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  records             = [azurerm_public_ip.gateway.ip_address]
}

resource "azurerm_subnet" "appgw" {
  name                 = "appgw"
  resource_group_name  = azurerm_resource_group.cx_backend.name
  virtual_network_name = azurerm_virtual_network.cx_backend.name
  address_prefixes     = ["10.0.8.0/24"]
}

resource "azurerm_application_gateway" "frontend" {
  name                = "${var.prefix}-gw"
  resource_group_name = azurerm_resource_group.gateway.name
  location            = azurerm_resource_group.gateway.location
  enable_http2        = true

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  autoscale_configuration {
    max_capacity = 2
    min_capacity = 1
  }

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }

  frontend_port {
    name = "port_80"
    port = 80
  }

  frontend_port {
    name = "port_443"
    port = 443
  }

  gateway_ip_configuration {
    name      = "gw_subnet"
    subnet_id = azurerm_subnet.appgw.id
  }

  http_listener {
    name                           = "anyhost_http"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "port_80"
    protocol                       = "Http"
  }

  http_listener {
    name                           = "anyhost_https"
    frontend_ip_configuration_name = "public"
    frontend_port_name             = "port_443"
    protocol                       = "Https"
    ssl_certificate_name           = "main_cert"
  }

  # Backend address pools

  backend_address_pool {
    name  = "cx_frontend"
    fqdns = [azurerm_linux_web_app.cx_frontend.default_hostname]
  }

  backend_address_pool {
    name  = "keycloak"
    fqdns = [azurerm_linux_web_app.keycloak.default_hostname]
  }

  # Backend HTTP settings
  #
  # Since our backends are App Service instances, we need to have
  # pick_host_name_from_backend_address be true, since that service does
  # name-based vhosting. In turn that means that parts of those servers need to
  # hard-code the "real" domain name to use.

  backend_http_settings {
    name                                = "rehost_http_setting"
    affinity_cookie_name                = "ApplicationGatewayAffinity"
    cookie_based_affinity               = "Disabled"
    pick_host_name_from_backend_address = true
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 20
    trusted_root_certificate_names      = []
  }

  # Request routing rules

  request_routing_rule {
    name               = "anyhost_https_path_routing"
    rule_type          = "PathBasedRouting"
    http_listener_name = "anyhost_https"
    url_path_map_name  = "main_path_map"
    priority           = 10020
  }

  request_routing_rule {
    name               = "anyhost_http_path_routing"
    rule_type          = "PathBasedRouting"
    http_listener_name = "anyhost_http"
    url_path_map_name  = "main_path_map"
    priority           = 10010
  }

  url_path_map {
    name                               = "main_path_map"
    default_backend_address_pool_name  = "cx_frontend"
    default_backend_http_settings_name = "rehost_http_setting"

    path_rule {
      name                       = "keycloak"
      backend_address_pool_name  = "keycloak"
      backend_http_settings_name = "rehost_http_setting"
      paths = [
        "/auth/*",
      ]
    }
  }

  ssl_certificate {
    name                = "main_cert"
    key_vault_secret_id = "https://wwtssl.vault.azure.net/secrets/wwtelescope-dev/"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.gateway.id]
  }

  lifecycle {
    prevent_destroy = true
  }
}


# Infra for linking up the App Gateway with an SSL cert managed by
# keyvault-acmebot.
#
# The gateway needs an identity to be able to access the keyvault with the cert,
# as I understand it.

resource "azurerm_user_assigned_identity" "gateway" {
  name                = "${var.prefix}-gw-ssl-ident"
  resource_group_name = azurerm_resource_group.gateway.name
  location            = azurerm_resource_group.gateway.location
}

resource "azurerm_key_vault_access_policy" "gw_cert" {
  # XXX TEMP
  #key_vault_id       = azurerm_key_vault.coreapp.id
  key_vault_id       = var.tmpVaultId
  tenant_id          = azurerm_user_assigned_identity.gateway.tenant_id
  object_id          = azurerm_user_assigned_identity.gateway.principal_id
  secret_permissions = ["Get"]
}

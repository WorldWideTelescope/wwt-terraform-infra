# Terraform definitions of WWT's web frontend: the App Gateway etc.

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

resource "azurerm_user_assigned_identity" "gateway" {
  name                = "wwtappgw1-ssl-mgd-identity"
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = azurerm_resource_group.web_frontend_legacy.location
}

resource "azurerm_application_gateway" "frontend" {
  name                = "wwtappgw1"
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = azurerm_resource_group.web_frontend_legacy.location
  enable_http2        = true

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.gateway.id]
  }

  autoscale_configuration {
    max_capacity = 20
    min_capacity = 2
  }

  frontend_ip_configuration {
    name                 = "appGwPublicFrontendIp"
    public_ip_address_id = azurerm_public_ip.frontend.id
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
    name      = "appGatewayIpConfig"
    subnet_id = "${azurerm_virtual_network.frontend.id}/subnets/subnet-1"
  }

  http_listener {
    name                           = "anyhost-http"
    frontend_ip_configuration_name = "appGwPublicFrontendIp"
    frontend_port_name             = "port_80"
    protocol                       = "Http"
  }

  http_listener {
    name                           = "anyhost-https"
    frontend_ip_configuration_name = "appGwPublicFrontendIp"
    frontend_port_name             = "port_443"
    protocol                       = "Https"
    ssl_certificate_name           = "anyhost-httpsvaultCert"
  }

  # Backend address pools

  backend_address_pool {
    # Although this backend is no longer used, if you try to get rid of it,
    # Terraform gets confused and wants to rewrite all of the other backends.
    name  = "wwtappgw1-vm-backend"
    fqdns = ["10.0.0.4", "10.0.0.5"]
  }

  backend_address_pool {
    name  = "wwtappgw1-proxy-backend"
    fqdns = [azurerm_linux_web_app.core_proxy.default_hostname]
  }

  backend_address_pool {
    name  = "wwtappgw1-static-backend"
    fqdns = [azurerm_storage_account.permanent_data_staticweb.primary_web_host]
  }

  backend_address_pool {
    name  = "wwtappgw1-nginx-core-prod-backend"
    fqdns = [azurerm_linux_web_app.core_nginx.default_hostname]
  }

  backend_address_pool {
    name  = "wwtappgw1-core-data-backend"
    fqdns = [azurerm_linux_web_app.data.default_hostname]
  }

  backend_address_pool {
    name  = "wwtappgw1-core-mvc-backend"
    fqdns = [azurerm_windows_web_app.communities.default_hostname]
  }

  backend_address_pool {
    name  = "keycloak"
    fqdns = [azurerm_linux_web_app.keycloak.default_hostname]
  }

  backend_address_pool {
    name  = "cx-frontend"
    fqdns = [azurerm_linux_web_app.cx_frontend.default_hostname]
  }

  # Backend HTTP settings
  #
  # Modifying this collection is tricky. If Terraform sees any disagreement
  # between its expectations and reality, it seems to want to recreate all of
  # the settings, which feels risky. Make changes through the Portal UI and then
  # then do a `terraform apply -refresh-only` to sync up Terraform's state with
  # the ground truth. That seems to work.

  backend_http_settings {
    name                  = "webstatic-http-setting"
    affinity_cookie_name  = "ApplicationGatewayAffinity"
    cookie_based_affinity = "Disabled"
    host_name             = azurerm_storage_account.permanent_data_staticweb.primary_web_host
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  backend_http_settings {
    name                                = "rehost-http-setting"
    affinity_cookie_name                = "ApplicationGatewayAffinity"
    cookie_based_affinity               = "Disabled"
    pick_host_name_from_backend_address = true
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 20
    trusted_root_certificate_names      = []
  }

  backend_http_settings {
    name                                = "corevm-http-setting"
    affinity_cookie_name                = "ApplicationGatewayAffinity"
    cookie_based_affinity               = "Disabled"
    host_name                           = "worldwidetelescope.org"
    pick_host_name_from_backend_address = false
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 20
    trusted_root_certificate_names      = []
  }

  backend_http_settings {
    name                                = "keycloak"
    cookie_based_affinity               = "Disabled"
    pick_host_name_from_backend_address = true
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 20
    trusted_root_certificate_names      = []
    probe_name                          = "keycloak"
  }

  # Probes

  probe {
    # Keycloak needs a custom probe since it only handles requests within the
    # /auth/ prefix.
    name                                      = "keycloak"
    pick_host_name_from_backend_http_settings = true
    interval                                  = 30
    timeout                                   = 30
    protocol                                  = "Http"
    path                                      = "/auth/"
    unhealthy_threshold                       = 3
  }

  # Request routing rules

  request_routing_rule {
    name               = "anyhost-https-path-routing"
    rule_type          = "PathBasedRouting"
    http_listener_name = "anyhost-https"
    url_path_map_name  = "anyhost-https-path-routing"
    priority           = 10020
  }

  request_routing_rule {
    name               = "anyhost-http-path-routing"
    rule_type          = "PathBasedRouting"
    http_listener_name = "anyhost-http"
    url_path_map_name  = "anyhost-http-path-routing"
    priority           = 10010
  }

  # First of two path maps that should be kept identical except for HTTP vs. HTTPS
  #
  # When adding rules with Terraform, you have to append them, otherwise Terraform
  # wants to delete-and-recreate them, which seems risky.
  url_path_map {
    name                               = "anyhost-https-path-routing"
    default_backend_address_pool_name  = "cx-frontend"
    default_backend_http_settings_name = "rehost-http-setting"
    default_rewrite_rule_set_name      = "global-cors-and-cache"

    path_rule {
      name                       = "proxy1"
      backend_address_pool_name  = "wwtappgw1-proxy-backend"
      backend_http_settings_name = "rehost-http-setting"
      rewrite_rule_set_name      = "global-cors-and-cache"
      paths = [
        "/webserviceproxy.aspx",
        "/wwtweb/webserviceproxy.aspx",
      ]
    }

    path_rule {
      name                       = "nginx-core-prod"
      backend_address_pool_name  = "wwtappgw1-nginx-core-prod-backend"
      backend_http_settings_name = "rehost-http-setting"
      paths = [
        "/docs/*",
        "/getinvolved*",
        "/support*",
        "/upgrade",
        "/webclient",
      ]
    }

    path_rule {
      name                       = "core-data"
      backend_address_pool_name  = "wwtappgw1-core-data-backend"
      backend_http_settings_name = "rehost-http-setting"
      paths = [
        "/wwtweb/*",
      ]
    }

    path_rule {
      name                       = "core-mvc"
      backend_address_pool_name  = "wwtappgw1-core-mvc-backend"
      backend_http_settings_name = "rehost-http-setting"
      paths = [
        "/Community*",
        "/Content*",
        "/Entity*",
        "/File*",
        "/LiveId*",
        "/Logout*",
        "/Profile*",
        "/Rating*",
        "/RatingConversion*",
        "/Resource*",
        "/Scripts*",
        "/Search*",
        "/WebServices*",
      ]
    }

    path_rule {
      name                       = "static"
      backend_address_pool_name  = "wwtappgw1-static-backend"
      backend_http_settings_name = "webstatic-http-setting"
      paths = [
        "/about*",
        "/assets/*",
        "/complete*",
        "/connect*",
        "/data/*",
        "/download*",
        "/engine/*",
        "/home*",
        "/html5sdk/*",
        "/images/*",
        "/learn*",
        "/style.css",
        "/terms*",
        "/testing_webclient/*",
        "/thumbnails/*",
        "/use*",
        "/webclient/*",
      ]
      rewrite_rule_set_name = "global-cors-and-cache"
    }

    path_rule {
      name                       = "keycloak"
      backend_address_pool_name  = "keycloak"
      backend_http_settings_name = "keycloak"
      paths = [
        "/auth/*",
      ]
    }

    path_rule {
      name                       = "cx-frontend"
      backend_address_pool_name  = "cx-frontend"
      backend_http_settings_name = "rehost-http-setting"
      paths = [
        "/@*",
        "/_cxadmin/*",
        "/_nuxt/*",
        "/silent-check-sso",
      ]
    }
  }

  # Second of two path maps that should be kept identical except for HTTP vs. HTTPS
  url_path_map {
    name                               = "anyhost-http-path-routing"
    default_backend_address_pool_name  = "cx-frontend"
    default_backend_http_settings_name = "rehost-http-setting"
    default_rewrite_rule_set_name      = "global-cors-and-cache"

    path_rule {
      name                       = "proxy-path-rule"
      backend_address_pool_name  = "wwtappgw1-proxy-backend"
      backend_http_settings_name = "rehost-http-setting"
      paths = [
        "/webserviceproxy.aspx",
        "/wwtweb/webserviceproxy.aspx",
      ]
      rewrite_rule_set_name = "global-cors-and-cache"
    }

    path_rule {
      name                       = "nginx-core-prod"
      backend_address_pool_name  = "wwtappgw1-nginx-core-prod-backend"
      backend_http_settings_name = "rehost-http-setting"
      paths = [
        "/docs/*",
        "/getinvolved*",
        "/support*",
        "/upgrade",
        "/webclient",
      ]
    }

    path_rule {
      name                       = "core-data"
      backend_address_pool_name  = "wwtappgw1-core-data-backend"
      backend_http_settings_name = "rehost-http-setting"
      paths = [
        "/wwtweb/*",
      ]
    }

    path_rule {
      name                       = "core-mvc"
      backend_address_pool_name  = "wwtappgw1-core-mvc-backend"
      backend_http_settings_name = "rehost-http-setting"
      paths = [
        "/Community*",
        "/Content*",
        "/Entity*",
        "/File*",
        "/LiveId*",
        "/Logout*",
        "/Profile*",
        "/Rating*",
        "/RatingConversion*",
        "/Resource*",
        "/Scripts*",
        "/Search*",
        "/WebServices*",
      ]
    }

    path_rule {
      name                       = "static"
      backend_address_pool_name  = "wwtappgw1-static-backend"
      backend_http_settings_name = "webstatic-http-setting"
      paths = [
        "/about*",
        "/assets/*",
        "/complete*",
        "/connect*",
        "/data/*",
        "/download*",
        "/engine/*",
        "/home*",
        "/html5sdk/*",
        "/images/*",
        "/learn*",
        "/style.css",
        "/terms*",
        "/testing_webclient/*",
        "/thumbnails/*",
        "/use*",
        "/webclient/*",
      ]
      rewrite_rule_set_name = "global-cors-and-cache"
    }

    path_rule {
      name                       = "keycloak"
      backend_address_pool_name  = "keycloak"
      backend_http_settings_name = "keycloak"
      paths = [
        "/auth/*",
      ]
    }

    path_rule {
      name                       = "cx-frontend"
      backend_address_pool_name  = "cx-frontend"
      backend_http_settings_name = "rehost-http-setting"
      paths = [
        "/@*",
        "/_cxadmin/*",
        "/_nuxt/*",
        "/silent-check-sso",
      ]
    }
  }

  rewrite_rule_set {
    name = "global-cors-and-cache"

    rewrite_rule {
      name          = "CORS"
      rule_sequence = 100

      response_header_configuration {
        header_name  = "Access-Control-Allow-Origin"
        header_value = "*"
      }

      response_header_configuration {
        header_name  = "Access-Control-Allow-Methods"
        header_value = "GET,POST,PUT,DELETE"
      }

      response_header_configuration {
        header_name  = "Access-Control-Allow-Headers"
        header_value = "Content-Disposition,Content-Encoding,Content-Type,LiveUserToken"
      }
    }

    rewrite_rule {
      name          = "Fix cache header"
      rule_sequence = 100

      condition {
        ignore_case = true
        negate      = false
        pattern     = "/wwtweb/.*"
        variable    = "var_uri_path"
      }

      response_header_configuration {
        header_name  = "Cache-Control"
        header_value = "public"
      }
    }
  }

  ssl_certificate {
    name                = "anyhost-httpsvaultCert"
    key_vault_secret_id = "${azurerm_key_vault.ssl.vault_uri}secrets/worldwidetelescope-org/"
  }

  lifecycle {
    prevent_destroy = true
  }
}

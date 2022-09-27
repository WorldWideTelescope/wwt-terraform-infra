# The CDN layer

resource "azurerm_cdn_profile" "main" {
  name                = "wwt-cdn-01"
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = "global"
  sku                 = "Standard_Microsoft"

  lifecycle {
    prevent_destroy = true
  }
}

# web.wwtassets.org

resource "azurerm_cdn_endpoint" "web" {
  name                = "wwtweb-prod"
  profile_name        = azurerm_cdn_profile.main.name
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = "global"

  is_compression_enabled        = true
  optimization_type             = "GeneralWebDelivery"
  origin_host_header            = "wwtwebstatic.z22.web.core.windows.net"
  querystring_caching_behaviour = "UseQueryString"

  origin {
    name      = "wwtwebstatic-blob-core-windows-net"
    host_name = "wwtwebstatic.z22.web.core.windows.net"
  }

  global_delivery_rule {
    modify_response_header_action {
      action = "Overwrite"
      name   = "Access-Control-Allow-Origin"
      value  = "*"
    }

    modify_response_header_action {
      action = "Overwrite"
      name   = "Access-Control-Allow-Methods"
      value  = "GET"
    }

    modify_response_header_action {
      action = "Overwrite"
      name   = "Access-Control-Allow-Headers"
      value  = "Content-Disposition,Content-Encoding,Content-Type"
    }
  }
}

resource "azurerm_cdn_endpoint_custom_domain" "web" {
  name = "web-wwtassets-org"
  # Capitalization consistency issue:
  cdn_endpoint_id = replace(azurerm_cdn_endpoint.web.id, "resourcegroups", "resourceGroups")
  host_name       = "web.wwtassets.org"

  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
    tls_version      = "TLS12"
  }
}

# data1.wwtassets.org

resource "azurerm_cdn_endpoint" "data1" {
  name                = "wwtdata1-prod"
  profile_name        = azurerm_cdn_profile.main.name
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = "global"

  is_compression_enabled = true
  optimization_type      = "GeneralWebDelivery"
  origin_host_header     = "wwtfiles.blob.core.windows.net"

  origin {
    name      = "wwtfiles-blob-core-windows-net"
    host_name = "wwtfiles.blob.core.windows.net"
  }
}

resource "azurerm_cdn_endpoint_custom_domain" "data1" {
  name = "data1-wwtassets-org"
  # Capitalization consistency issue:
  cdn_endpoint_id = replace(azurerm_cdn_endpoint.data1.id, "resourcegroups", "resourceGroups")
  host_name       = "data1.wwtassets.org"

  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
    tls_version      = "TLS12"
  }
}

# docs.worldwidetelescope.org

resource "azurerm_cdn_endpoint" "webdocs" {
  name                = "wwtwebdocs-prod"
  profile_name        = azurerm_cdn_profile.main.name
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = "global"

  is_compression_enabled = true
  optimization_type      = "GeneralWebDelivery"
  origin_host_header     = "wwtwebstatic.z22.web.core.windows.net"
  origin_path            = "/_docs"

  origin {
    name      = "wwtwebstatic-z22-web-core-windows-net"
    host_name = "wwtwebstatic.z22.web.core.windows.net"
  }
}

resource "azurerm_cdn_endpoint_custom_domain" "webdocs" {
  name = "docs-worldwidetelescope-org"
  # Capitalization consistency issue:
  cdn_endpoint_id = replace(azurerm_cdn_endpoint.webdocs.id, "resourcegroups", "resourceGroups")
  host_name       = "docs.worldwidetelescope.org"

  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
    tls_version      = "TLS12"
  }
}

# embed.worldwidetelescope.org

resource "azurerm_cdn_endpoint" "embed" {
  name                = "wwtwebembed-prod"
  profile_name        = azurerm_cdn_profile.main.name
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = "global"

  is_compression_enabled = true
  optimization_type      = "GeneralWebDelivery"
  origin_host_header     = "wwtwebstatic.z22.web.core.windows.net"
  origin_path            = "/_embedui/"

  origin {
    name      = "wwtwebstatic-z22-web-core-windows-net"
    host_name = "wwtwebstatic.z22.web.core.windows.net"
  }
}

resource "azurerm_cdn_endpoint_custom_domain" "embed" {
  name = "embed-worldwidetelescope-org"
  # Capitalization consistency issue:
  cdn_endpoint_id = replace(azurerm_cdn_endpoint.embed.id, "resourcegroups", "resourceGroups")
  host_name       = "embed.worldwidetelescope.org"

  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
    tls_version      = "TLS12"
  }
}

# cdn.worldwidetelescope.org

resource "azurerm_cdn_endpoint" "general" {
  name                = "wwt-prod"
  profile_name        = azurerm_cdn_profile.main.name
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = "global"

  is_compression_enabled        = true
  optimization_type             = "GeneralWebDelivery"
  origin_host_header            = "worldwidetelescope.org"
  querystring_caching_behaviour = "UseQueryString"

  global_delivery_rule {
    modify_response_header_action {
      action = "Overwrite"
      name   = "Access-Control-Allow-Origin"
      value  = "*"
    }

    modify_response_header_action {
      action = "Overwrite"
      name   = "Access-Control-Allow-Methods"
      value  = "GET,POST,PUT,DELETE"
    }

    modify_response_header_action {
      action = "Overwrite"
      name   = "Access-Control-Allow-Headers"
      value  = "Content-Disposition,Content-Encoding,Content-Type,LiveUserToken"
    }
  }
  origin {
    name      = "beta-worldwidetelescope-org"
    host_name = "worldwidetelescope.org"
  }
}

resource "azurerm_cdn_endpoint_custom_domain" "general" {
  name = "cdn-worldwidetelescope-org"
  # Capitalization consistency issue:
  cdn_endpoint_id = replace(azurerm_cdn_endpoint.general.id, "resourcegroups", "resourceGroups")
  host_name       = "cdn.worldwidetelescope.org"

  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
    tls_version      = "TLS12"
  }
}

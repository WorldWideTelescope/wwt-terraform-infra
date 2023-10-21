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
  origin_host_header            = azurerm_storage_account.permanent_data_staticweb.primary_web_host
  querystring_caching_behaviour = "UseQueryString"

  origin {
    name      = "wwtwebstatic-blob-core-windows-net"
    host_name = azurerm_storage_account.permanent_data_staticweb.primary_web_host
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

  lifecycle {
    prevent_destroy = true
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

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    azurerm_dns_cname_record.assets_web,
  ]
}

resource "azurerm_dns_cname_record" "assets_web" {
  name                = "web"
  resource_group_name = azurerm_dns_zone.assets.resource_group_name
  zone_name           = azurerm_dns_zone.assets.name
  ttl                 = 3600
  target_resource_id  = azurerm_cdn_endpoint.web.id
}


# data1.wwtassets.org

resource "azurerm_cdn_endpoint" "data1" {
  name                = "wwtdata1-prod"
  profile_name        = azurerm_cdn_profile.main.name
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = "global"

  is_compression_enabled = true
  optimization_type      = "GeneralWebDelivery"
  origin_host_header     = azurerm_storage_account.permanent_data_core.primary_blob_host

  origin {
    name      = "wwtfiles-blob-core-windows-net"
    host_name = azurerm_storage_account.permanent_data_core.primary_blob_host
  }

  lifecycle {
    prevent_destroy = true
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

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    azurerm_dns_cname_record.assets_data1,
  ]
}

resource "azurerm_dns_cname_record" "assets_data1" {
  name                = "data1"
  resource_group_name = azurerm_dns_zone.assets.resource_group_name
  zone_name           = azurerm_dns_zone.assets.name
  ttl                 = 3600
  target_resource_id  = azurerm_cdn_endpoint.data1.id
}

# cx.wwtassets.org

resource "azurerm_cdn_endpoint" "cxdata" {
  name                = "${var.prefix}-cxdata"
  profile_name        = azurerm_cdn_profile.main.name
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = "global"

  optimization_type             = "GeneralWebDelivery"
  origin_host_header            = azurerm_storage_account.constellations.primary_blob_host
  querystring_caching_behaviour = "UseQueryString"

  origin {
    name      = "constellations"
    host_name = azurerm_storage_account.constellations.primary_blob_host
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

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_cdn_endpoint_custom_domain" "cxdata" {
  name = "${var.prefix}-cxdata"
  # Capitalization consistency issue:
  cdn_endpoint_id = replace(azurerm_cdn_endpoint.cxdata.id, "resourcegroups", "resourceGroups")
  host_name       = "cx.wwtassets.org"

  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
    tls_version      = "TLS12"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    azurerm_dns_cname_record.assets_cx,
  ]
}

resource "azurerm_dns_cname_record" "assets_cx" {
  name                = "cx"
  resource_group_name = azurerm_dns_zone.assets.resource_group_name
  zone_name           = azurerm_dns_zone.assets.name
  ttl                 = 3600
  target_resource_id  = azurerm_cdn_endpoint.cxdata.id
}

# docs.worldwidetelescope.org

resource "azurerm_cdn_endpoint" "webdocs" {
  name                = "wwtwebdocs-prod"
  profile_name        = azurerm_cdn_profile.main.name
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = "global"

  is_compression_enabled = true
  optimization_type      = "GeneralWebDelivery"
  origin_host_header     = azurerm_storage_account.permanent_data_staticweb.primary_web_host
  origin_path            = "/_docs"

  origin {
    name      = "wwtwebstatic-z22-web-core-windows-net"
    host_name = azurerm_storage_account.permanent_data_staticweb.primary_web_host
  }

  lifecycle {
    prevent_destroy = true
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

  lifecycle {
    prevent_destroy = true
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
  origin_host_header     = azurerm_storage_account.permanent_data_staticweb.primary_web_host
  origin_path            = "/_embedui/"

  origin {
    name      = "wwtwebstatic-z22-web-core-windows-net"
    host_name = azurerm_storage_account.permanent_data_staticweb.primary_web_host
  }

  lifecycle {
    prevent_destroy = true
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

  lifecycle {
    prevent_destroy = true
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

  lifecycle {
    prevent_destroy = true
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

  lifecycle {
    prevent_destroy = true
  }
}

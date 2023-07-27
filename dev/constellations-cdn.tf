# The CDN layer

resource "azurerm_resource_group" "cx_cdn" {
  name     = "${var.prefix}-cxcdn"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_cdn_profile" "cx" {
  name                = "${var.prefix}-cx"
  resource_group_name = azurerm_resource_group.cx_cdn.name
  location            = "global"
  sku                 = "Standard_Microsoft"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_cdn_endpoint" "cxdata" {
  name                = "${var.prefix}-cxdata"
  profile_name        = azurerm_cdn_profile.cx.name
  resource_group_name = azurerm_resource_group.cx_cdn.name
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
  host_name       = "assets.${var.tld}"

  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
    tls_version      = "TLS12"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    azurerm_dns_cname_record.assets,
  ]
}

resource "azurerm_dns_cname_record" "assets" {
  name                = "assets"
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name # must be same as the zone
  zone_name           = azurerm_dns_zone.flagship.name
  ttl                 = 3600
  target_resource_id  = azurerm_cdn_endpoint.cxdata.id
}

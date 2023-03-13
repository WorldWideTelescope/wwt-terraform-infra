# The WWT tour-making contest website (2021-2022)

resource "azurerm_cdn_endpoint" "contest" {
  name                = "${var.prefix}-contest"
  profile_name        = azurerm_cdn_profile.main.name
  resource_group_name = azurerm_resource_group.web_frontend_legacy.name
  location            = "global"

  optimization_type  = "GeneralWebDelivery"
  origin_host_header = azurerm_storage_account.permanent_data_staticweb.primary_web_host
  origin_path        = "/_contest/"

  origin {
    name      = "origin1"
    host_name = azurerm_storage_account.permanent_data_staticweb.primary_web_host
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_dns_cname_record" "contest" {
  name                = "contest"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  record              = azurerm_cdn_endpoint.contest.fqdn
}

resource "azurerm_cdn_endpoint_custom_domain" "contest" {
  name = "contest-worldwidetelescope-org"
  # Capitalization consistency issue:
  cdn_endpoint_id = replace(azurerm_cdn_endpoint.contest.id, "resourcegroups", "resourceGroups")
  host_name       = "contest.worldwidetelescope.org"

  cdn_managed_https {
    certificate_type = "Dedicated"
    protocol_type    = "ServerNameIndication"
    tls_version      = "TLS12"
  }

  lifecycle {
    prevent_destroy = true
  }
}

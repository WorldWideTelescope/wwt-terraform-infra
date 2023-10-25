# The DNS configuration.
#
# Not (yet) described for the flagship:
# - @ SOA record
# - @ NS record
# - `mail` A record
# - `mail` MX record

resource "azurerm_dns_zone" "flagship" {
  name                = "worldwidetelescope.org"
  resource_group_name = azurerm_resource_group.support.name

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_dns_a_record" "root_a" {
  name                = "@"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  records             = [azurerm_public_ip.frontend.ip_address]
}

resource "azurerm_dns_txt_record" "root_txt" {
  name                = "@"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600

  record {
    value = "v=spf1 a mx include:sendgrid.net ~all"
  }

  record {
    value = "MS=ms25610440"
  }

  record {
    value = "google-site-verification=${var.googleSiteVerificationTag1}"
  }

  record {
    value = "google-site-verification=${var.googleSiteVerificationTag2}"
  }
}

resource "azurerm_dns_mx_record" "root_mx" {
  name                = "@"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600

  record {
    preference = 1
    exchange   = "aspmx.l.google.com."
  }

  record {
    preference = 5
    exchange   = "alt1.aspmx.l.google.com."
  }

  record {
    preference = 5
    exchange   = "alt2.aspmx.l.google.com."
  }

  record {
    preference = 10
    exchange   = "alt3.aspmx.l.google.com."
  }

  record {
    preference = 10
    exchange   = "alt4.aspmx.l.google.com."
  }
}

resource "azurerm_dns_cname_record" "www" {
  name                = "www"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  record              = "worldwidetelescope.org."
}

# CDN wrapper

resource "azurerm_dns_cname_record" "cdn" {
  name                = "cdn"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  record              = "${azurerm_cdn_endpoint.general.fqdn}."
}

# Docs site

resource "azurerm_dns_cname_record" "docs" {
  name                = "docs"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  record              = azurerm_cdn_endpoint.webdocs.fqdn
}

# Embed creator site

resource "azurerm_dns_cname_record" "embed" {
  name                = "embed"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  record              = azurerm_cdn_endpoint.embed.fqdn
}

# StarHunt project (Jonathan Tan group)

resource "azurerm_dns_cname_record" "starhunt" {
  name                = "starhunt"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  record              = "chalmersstarhunt.z13.web.core.windows.net"
}

# Forum redirects

resource "azurerm_dns_cname_record" "forum" {
  name                = "forum"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  record              = "${azurerm_linux_web_app.core_nginx.default_hostname}."
}

resource "azurerm_dns_cname_record" "forums" {
  name                = "forums"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  record              = "${azurerm_linux_web_app.core_nginx.default_hostname}."
}

resource "azurerm_dns_txt_record" "forum_verify" {
  name                = "asuid.forum"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600

  record {
    value = lower(azurerm_linux_web_app.core_nginx.custom_domain_verification_id)
  }
}

resource "azurerm_dns_txt_record" "forums_verify" {
  name                = "asuid.forums"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600

  record {
    value = lower(azurerm_linux_web_app.core_nginx.custom_domain_verification_id)
  }
}

# "beta" domain from when we were reengineering the whole web stack

resource "azurerm_dns_a_record" "beta" {
  name                = "beta"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  records             = [azurerm_public_ip.frontend.ip_address]
}

resource "azurerm_dns_cname_record" "beta-cdn" {
  name                = "beta-cdn"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  record              = azurerm_cdn_endpoint.general.fqdn
}

# Ancient "content" subdomain, no longer used??

resource "azurerm_dns_cname_record" "content" {
  name                = "content"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  record              = "wwtelescope.vo.msecnd.net."
}

# wwtassets.org zone

resource "azurerm_dns_zone" "assets" {
  name                = "wwtassets.org"
  resource_group_name = azurerm_resource_group.support.name

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_dns_a_record" "assets_root" {
  name                = "@"
  zone_name           = azurerm_dns_zone.assets.name
  resource_group_name = azurerm_dns_zone.assets.resource_group_name
  ttl                 = 3600
  records             = [azurerm_linux_web_app.core_nginx.outbound_ip_address_list[length(azurerm_linux_web_app.core_nginx.outbound_ip_address_list) - 1]]
}

resource "azurerm_dns_txt_record" "assets_root" {
  name                = "@"
  zone_name           = azurerm_dns_zone.assets.name
  resource_group_name = azurerm_dns_zone.assets.resource_group_name
  ttl                 = 3600

  record {
    value = "${azurerm_linux_web_app.core_nginx.default_hostname}."
  }
}

resource "azurerm_dns_txt_record" "assets_verify" {
  name                = "asuid"
  zone_name           = azurerm_dns_zone.assets.name
  resource_group_name = azurerm_dns_zone.assets.resource_group_name
  ttl                 = 3600

  record {
    value = lower(azurerm_linux_web_app.core_nginx.custom_domain_verification_id)
  }
}

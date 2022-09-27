# The DNS configuration.
#
# Not (yet) described here:
# - @ SOA record
# - @ NS record
# - @ MX record
# - @ TXT record
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

# Tour contest website

resource "azurerm_dns_a_record" "contest" {
  name                = "contest"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  records             = ["52.149.174.223"]
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

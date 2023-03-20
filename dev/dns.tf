# The base DNS configuration.

resource "azurerm_dns_zone" "flagship" {
  name                = var.tld
  resource_group_name = azurerm_resource_group.permanent.name

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_dns_cname_record" "www" {
  name                = "www"
  zone_name           = azurerm_dns_zone.flagship.name
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  ttl                 = 3600
  record              = "${var.tld}."
}

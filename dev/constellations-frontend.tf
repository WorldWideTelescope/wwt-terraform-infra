# The frontend of the Constellations web app.

resource "azurerm_resource_group" "cx_frontend" {
  name     = "${var.prefix}-cxfrontend"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

# The app
#
# We are piggybacking on the app service plan for the backend. I think that
# is wise? I don't know but I assume that more apps in one plan is better
# than a plan per app.

resource "azurerm_linux_web_app" "cx_frontend" {
  name                = "${var.prefix}-cxfe"
  location            = azurerm_resource_group.cx_frontend.location
  resource_group_name = azurerm_resource_group.cx_frontend.name
  service_plan_id     = azurerm_service_plan.cx_backend.id

  app_settings = {
    "NUXT_PUBLIC_API_URL"              = "https://api.${var.tld}"
    "NUXT_PUBLIC_GOOGLE_ANALYTICS_TAG" = var.googleAnalyticsTag
    "NUXT_PUBLIC_HOST_URL"             = "https://${var.tld}"
    "NUXT_PUBLIC_KEYCLOAK_URL"         = "https://${var.tld}/auth"
  }

  site_config {
    always_on  = false
    ftps_state = "FtpsOnly"

    # A funky custom start command is needed because our Zip-based deployment
    # breaks symlinks in the app tree, and nodejs ends up having a problem
    # running `.bin/nuxt` because it doesn't realize that it should be treated
    # as an `.mjs` file.
    app_command_line = "node node_modules/nuxt/bin/nuxt.mjs start"
  }
}

# Set up the TLD as a custom domain for the app
#
# TODO: some of the app gateway docs suggested that one still wants to do this
# when the app is behind a gateway, so I'm leaving this config here for now. But
# it seems like maybe it should go away or it will break?

resource "azurerm_dns_txt_record" "cx_root_verify" {
  name                = "asuid"
  resource_group_name = azurerm_dns_zone.flagship.resource_group_name
  zone_name           = azurerm_dns_zone.flagship.name
  ttl                 = 3600

  record {
    value = lower(azurerm_linux_web_app.cx_frontend.custom_domain_verification_id)
  }
}

resource "azurerm_app_service_custom_hostname_binding" "cx_frontend" {
  hostname            = var.tld
  resource_group_name = azurerm_resource_group.cx_frontend.name
  app_service_name    = azurerm_linux_web_app.cx_frontend.name

  # These are managed through the cert binding:
  lifecycle {
    ignore_changes = [ssl_state, thumbprint]
  }

  depends_on = [
    azurerm_dns_txt_record.cx_root_verify,
  ]
}

resource "azurerm_app_service_managed_certificate" "cx_frontend" {
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.cx_frontend.id
}

resource "azurerm_app_service_certificate_binding" "cx_frontend" {
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.cx_frontend.id
  certificate_id      = azurerm_app_service_managed_certificate.cx_frontend.id
  ssl_state           = "SniEnabled"
}

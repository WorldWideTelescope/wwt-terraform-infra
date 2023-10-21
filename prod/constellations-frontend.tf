# The frontend of the Constellations web app.
#
# We are piggybacking on the app service plan for the backend. I think that is
# wise? I don't know but I assume that more apps in one plan is better than a
# plan per app.
#
# (Note that the app doesn't need to be in the same resource group as the app
# service, but a frontend resource group for just the one app seems a little
# pointless.)

##resource "azurerm_resource_group" "cx_frontend" {
##  name     = "${var.prefix}-cxfrontend"
##  location = var.location
##
##  lifecycle {
##    prevent_destroy = true
##  }
##}

resource "azurerm_linux_web_app" "cx_frontend" {
  name                = "${var.prefix}-cxfe"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  service_plan_id     = azurerm_service_plan.cx_backend.id

  app_settings = {
    "NUXT_PUBLIC_API_URL"              = "https://api.${var.tld}"
    "NUXT_PUBLIC_GOOGLE_ANALYTICS_TAG" = var.googleAnalyticsTag
    "NUXT_PUBLIC_HOST_URL"             = "https://${var.tld}"
    "NUXT_PUBLIC_KEYCLOAK_URL"         = "https://${var.tld}/auth"
  }

  site_config {
    always_on  = true
    ftps_state = "FtpsOnly"

    # A funky custom start command is needed because our Zip-based deployment
    # breaks symlinks in the app tree, and nodejs ends up having a problem
    # running `.bin/nuxt` because it doesn't realize that it should be treated
    # as an `.mjs` file.
    app_command_line = "node node_modules/nuxt/bin/nuxt.mjs start"
  }
}

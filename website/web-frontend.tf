# Terraform definitions of WWT's web frontend: the App Gateway, CDN setup, etc.

resource "azurerm_resource_group" "web_frontend_legacy" {
  name     = var.legacyNameFrontendGroup
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

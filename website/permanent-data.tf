# Terraform definitions of WWT's permanent data resources. These mostly exist so
# that other more actively evolving resources can reference them.

resource "azurerm_resource_group" "permanent_data" {
  name     = "permanent-data"
  location = var.location
}

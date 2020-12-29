# Terraform definitions of WWT's permanent data resources. These mostly exist so
# that other more actively evolving resources can reference them.

resource "azurerm_resource_group" "permanent_data" {
  name     = "permanent-data"
  location = var.location
}

resource "azurerm_storage_account" "permanent_data_wwtweb" {
  name                      = var.legacyNameWwtweb
  resource_group_name       = azurerm_resource_group.permanent_data.name
  location                  = azurerm_resource_group.permanent_data.location
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = false
}

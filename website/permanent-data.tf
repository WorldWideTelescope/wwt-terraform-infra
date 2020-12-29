# Terraform definitions of WWT's permanent data resources. These mostly exist so
# that other more actively evolving resources can reference them.

resource "azurerm_resource_group" "permanent_data" {
  name     = "permanent-data"
  location = var.location
}

// The "wwtweb" storage account hosts miscellaneous data files, including the
// `/drops/` blob container traditionally used to host release artifacts.
resource "azurerm_storage_account" "permanent_data_wwtweb" {
  name                      = var.legacyNameWwtweb
  resource_group_name       = azurerm_resource_group.permanent_data.name
  location                  = azurerm_resource_group.permanent_data.location
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = false
}

// The "communities" storage account hosts data associated with the Communities
// web app.
resource "azurerm_storage_account" "permanent_data_communities" {
  name                      = var.legacyNameCommunities
  resource_group_name       = azurerm_resource_group.permanent_data.name
  location                  = azurerm_resource_group.permanent_data.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = false
}

// The "wwtwebstatic" storage account has static web service enabled (in the $web container)
// and hosts core static-web resources like documentation and the engine Javascript.
resource "azurerm_storage_account" "permanent_data_staticweb" {
  name                      = var.legacyNameWwtwebstatic
  resource_group_name       = azurerm_resource_group.permanent_data.name
  location                  = azurerm_resource_group.permanent_data.location
  account_tier              = "Standard"
  account_replication_type  = "RAGRS"
  enable_https_traffic_only = false

  static_website {
    error_404_document = "404.html"
    index_document     = "index.html"
  }
}

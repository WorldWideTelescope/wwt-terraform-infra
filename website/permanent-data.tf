# Terraform definitions of WWT's permanent data resources. These mostly exist so
# that other more actively evolving resources can reference them.

resource "azurerm_resource_group" "permanent_data" {
  name     = "permanent-data"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

// The "wwtweb" storage account hosts miscellaneous data files, including the
// `/drops/` blob container traditionally used to host release artifacts.
resource "azurerm_storage_account" "permanent_data_wwtweb" {
  name                      = var.legacyNameWwtwebStorage
  resource_group_name       = azurerm_resource_group.permanent_data.name
  location                  = azurerm_resource_group.permanent_data.location
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = false

  lifecycle {
    prevent_destroy = true
  }
}

// The "communities" storage account hosts data associated with the Communities
// web app.
resource "azurerm_storage_account" "permanent_data_communities" {
  name                      = var.legacyNameCommunitiesStorage
  resource_group_name       = azurerm_resource_group.permanent_data.name
  location                  = azurerm_resource_group.permanent_data.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = false

  lifecycle {
    prevent_destroy = true
  }
}

// The "wwtwebstatic" storage account has static web service enabled (in the $web container)
// and hosts core static-web resources like documentation and the engine Javascript.
resource "azurerm_storage_account" "permanent_data_staticweb" {
  name                      = var.legacyNameWwtwebstaticStorage
  resource_group_name       = azurerm_resource_group.permanent_data.name
  location                  = azurerm_resource_group.permanent_data.location
  account_tier              = "Standard"
  account_replication_type  = "RAGRS"
  enable_https_traffic_only = false

  static_website {
    error_404_document = "404.html"
    index_document     = "index.html"
  }

  lifecycle {
    prevent_destroy = true
  }
}

// The "mars" storage account hosts Mars imagery, including HiRISE (~12 TiB)
resource "azurerm_storage_account" "permanent_data_mars" {
  name                      = var.legacyNameMarsStorage
  resource_group_name       = azurerm_resource_group.permanent_data.name
  location                  = azurerm_resource_group.permanent_data.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_https_traffic_only = false

  lifecycle {
    prevent_destroy = true
  }
}

// The "wwtcore" database server hosts the AstroObjects and WWTTours databases.
resource "azurerm_sql_server" "permanent_data_wwtcore_db_server" {
  name                         = var.legacyNameWwtcoreDBServer
  resource_group_name          = azurerm_resource_group.permanent_data.name
  location                     = azurerm_resource_group.permanent_data.location
  version                      = "12.0"
  administrator_login          = "wwtuser"
  administrator_login_password = var.wwtcoreDbAdminPassword

  lifecycle {
    prevent_destroy = true
  }
}

// The "communities" database server hosts the Layerscape database.
resource "azurerm_sql_server" "permanent_data_communities_db_server" {
  name                         = var.legacyNameCommunitiesDBServer
  resource_group_name          = azurerm_resource_group.permanent_data.name
  location                     = azurerm_resource_group.permanent_data.location
  version                      = "12.0"
  administrator_login          = "wwtprod"
  administrator_login_password = var.communitiesDbAdminPassword

  lifecycle {
    prevent_destroy = true
  }
}

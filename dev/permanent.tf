# The resource group for things that should never be deleted.

resource "azurerm_resource_group" "permanent" {
  name     = "${var.prefix}-permanent"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_account" "constellations" {
  name                      = "${var.prefix}cxdata"
  resource_group_name       = azurerm_resource_group.permanent.name
  location                  = azurerm_resource_group.permanent.location
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = false
  min_tls_version           = "TLS1_0" # added to reflect ground truth 2022-Sep

  lifecycle {
    prevent_destroy = true
  }
}

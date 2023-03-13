# The resource group for things that should never be deleted.

resource "azurerm_resource_group" "permanent" {
  name     = "${var.prefix}-permanent"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

# The frontend of the Constellations web app.

resource "azurerm_resource_group" "cx_frontend" {
  name     = "${var.prefix}-cxfrontend"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

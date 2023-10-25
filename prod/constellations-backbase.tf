# Base-layer infrastructure for the Constellations backend services.
#
# Because the MongoDB is isolated on a private network, the usual Azure admin
# systems do not work. However, with the bastion host setup defined in
# `constellations-bastion.tf`, it is possible to administer the database
# locally.
#
# 1. First, set up the bastion and SSH into it.
# 2. Forward a port to the DB:
#    ```
#    ssh -O forward -L 10255:wwtprod-cxbe-server.mongo.cosmos.azure.com:10255 wwt@wwtprodcxb.westus.cloudapp.azure.com
#    ```
# 3. Make a temporary connection string, replacing the `...cosmos.azure.com` hostname
#    with `localhost`. You can get the connection string from the database's admin
#    page in the Azure Portal.
# 4. Connect using pymongo with some special settings:
#     ```
#     conn = pymongo.MongoClient(cs, tlsAllowInvalidCertificates=True, directConnection=True)
#     ```
#     where `cs` is the temporary connection string.

resource "azurerm_resource_group" "cx_backend" {
  name     = "${var.prefix}-cxbackend"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

# App service plan for the backend services. The hope is that these will scale
# more or less in unison ...

resource "azurerm_service_plan" "cx_backend" {
  name                = "${var.prefix}cxbackend"
  resource_group_name = azurerm_resource_group.cx_backend.name
  location            = azurerm_resource_group.cx_backend.location
  os_type             = "Linux"
  sku_name            = "P1v2"
}

# The backend virtual network

resource "azurerm_virtual_network" "cx_backend" {
  name                = "${var.prefix}-cxbeVnet"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "cx_backend_main" {
  name                 = "${var.prefix}-cxbeSubnet"
  resource_group_name  = azurerm_resource_group.cx_backend.name
  virtual_network_name = azurerm_virtual_network.cx_backend.name
  address_prefixes     = ["10.0.0.0/24"]
}

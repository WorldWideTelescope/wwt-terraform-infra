# The CosmosDB (MongoDB-alike) for the Constellations framework.
#
# Because the database is isolated on a private network, the usual Azure admin
# systems do not work. However, with the bastion host setup defined in
# `constellations-bastion.tf`, it is possible to administer the database
# locally.
#
# 1. First, set up the bastion and SSH into it.
# 2. Forward a port to the DB:
#    ```
#    ssh -O forward -L 10255:wwtprod-cxbe-nosql.mongo.cosmos.azure.com:10255 wwt@wwtprodcxb.westus.cloudapp.azure.com
#    ```
# 3. Make a temporary connection string, replacing the `...cosmos.azure.com`
#    hostname with `localhost`. You can get the connection string from the
#    database's admin page in the Azure Portal.
# 4. Connect using pymongo with some special settings:
#     ```
#     conn = pymongo.MongoClient(cs, tlsAllowInvalidCertificates=True, directConnection=True)
#     ```
#     where `cs` is the temporary connection string.

resource "azurerm_cosmosdb_account" "cx_backend" {
  name                = "${var.prefix}-cxbe-nosql"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  geo_location {
    location          = azurerm_resource_group.cx_backend.location
    failover_priority = 0
  }

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }
}

# Supporting vnet/private-endpoint stuff

resource "azurerm_private_dns_zone" "cx_backend" {
  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = azurerm_resource_group.cx_backend.name
}

resource "azurerm_private_endpoint" "cx_backend" {
  name                = "${var.prefix}-cxbeDbEndpoint"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  subnet_id           = azurerm_subnet.cx_backend_main.id

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.cx_backend.id]
  }

  private_service_connection {
    name                           = "${var.prefix}-cxbeDbEndpoint"
    private_connection_resource_id = replace(azurerm_cosmosdb_account.cx_backend.id, "DocumentDB", "DocumentDb")
    is_manual_connection           = false
    subresource_names              = ["MongoDB"]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "cx_backend" {
  name                  = "privatelink.mongo.cosmos.azure.com-dblink"
  resource_group_name   = azurerm_resource_group.cx_backend.name
  private_dns_zone_name = azurerm_private_dns_zone.cx_backend.name
  virtual_network_id    = azurerm_virtual_network.cx_backend.id
}

resource "azurerm_private_dns_a_record" "cx_backend_nosql" {
  name                = "${var.prefix}-cxbe-nosql"
  zone_name           = azurerm_private_dns_zone.cx_backend.name
  resource_group_name = azurerm_resource_group.cx_backend.name
  ttl                 = 10
  records             = ["10.0.0.4"]
}

resource "azurerm_private_dns_a_record" "cx_backend_nosql_loc" {
  name                = "${var.prefix}-cxbe-nosql-${azurerm_resource_group.cx_backend.location}"
  zone_name           = azurerm_private_dns_zone.cx_backend.name
  resource_group_name = azurerm_resource_group.cx_backend.name
  ttl                 = 10
  records             = ["10.0.0.5"]
}

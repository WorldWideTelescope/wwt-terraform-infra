# The backing database for the Constellations Keycloak service
#
# See remarks in `constellations-backbase.tf` for some information that can
# hopefully be used to directly connect to this server, if ever needed.

resource "azurerm_postgresql_server" "cxsql" {
  name                = "${var.prefix}-cxsql"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name

  sku_name                     = "GP_Gen5_2"
  version                      = "11"
  storage_mb                   = 16384
  backup_retention_days        = 35
  geo_redundant_backup_enabled = true
  auto_grow_enabled            = true

  public_network_access_enabled     = false
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
  infrastructure_encryption_enabled = false

  administrator_login          = "psqladmin"
  administrator_login_password = var.cxsqlAdminPassword
}

resource "azurerm_postgresql_database" "keycloak" {
  name                = "keycloak"
  resource_group_name = azurerm_resource_group.cx_backend.name
  server_name         = azurerm_postgresql_server.cxsql.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

# Supporting vnet/private-endpoint stuff

resource "azurerm_subnet" "cx_backend_sql" {
  name                 = "${var.prefix}-cxbeSqlSubnet"
  resource_group_name  = azurerm_resource_group.cx_backend.name
  virtual_network_name = azurerm_virtual_network.cx_backend.name
  address_prefixes     = ["10.0.4.0/24"]
}

resource "azurerm_private_dns_zone" "cx_sql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.cx_backend.name
}

resource "azurerm_private_endpoint" "cx_backend_sql" {
  name                = "${var.prefix}-cxbeSqlEndpoint"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  subnet_id           = azurerm_subnet.cx_backend_sql.id

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.cx_sql.id]
  }

  private_service_connection {
    name                           = "${var.prefix}-cxbeSqlEndpoint"
    private_connection_resource_id = azurerm_postgresql_server.cxsql.id
    is_manual_connection           = false
    subresource_names              = ["postgresqlServer"]
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "cx_sql" {
  name                  = "privatelink.postgres.database.azure.com-sqllink"
  resource_group_name   = azurerm_resource_group.cx_backend.name
  private_dns_zone_name = azurerm_private_dns_zone.cx_sql.name
  virtual_network_id    = azurerm_virtual_network.cx_backend.id
}

resource "azurerm_private_dns_a_record" "cx_backend_sql" {
  name                = "${var.prefix}-cxsql"
  zone_name           = azurerm_private_dns_zone.cx_sql.name
  resource_group_name = azurerm_resource_group.cx_backend.name
  ttl                 = 10
  records             = ["10.0.4.4"]

  tags = {
    # Even when we create using Terraform, this tag gets auto-added
    "creator" = "created by private endpoint wwtprod-cxbeSqlEndpoint with resource guid 5b0a25e2-8040-4ce1-8ace-eae834d4fbb1"
  }
}

resource "azurerm_private_dns_a_record" "cx_backend_sql_loc" {
  name                = "${var.prefix}-cxsql-${azurerm_resource_group.cx_backend.location}"
  zone_name           = azurerm_private_dns_zone.cx_sql.name
  resource_group_name = azurerm_resource_group.cx_backend.name
  ttl                 = 10
  records             = ["10.0.4.5"]
}

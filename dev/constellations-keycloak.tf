# The Keycloak service and backing database for Constellations

# The backing PostgreSQL storage database

resource "azurerm_postgresql_server" "cxsql" {
  name                = "${var.prefix}-cxsql"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name

  sku_name                     = "GP_Gen5_2"
  version                      = "11"
  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = false

  public_network_access_enabled     = false
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
  infrastructure_encryption_enabled = false

  administrator_login          = "psqladmin"
  administrator_login_password = var.cxsqlAdminPassword
}

resource "azurerm_subnet" "cx_backend_sql" {
  name                 = "${var.prefix}-cxbeSqlSubnet"
  resource_group_name  = azurerm_resource_group.cx_backend.name
  virtual_network_name = azurerm_virtual_network.cx_backend.name
  address_prefixes     = ["10.0.4.0/24"]
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

# Private DNS zone for the SQL stuff

resource "azurerm_private_dns_zone" "cx_sql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.cx_backend.name
}

resource "azurerm_private_dns_a_record" "cx_backend_sql" {
  name                = "${var.prefix}-cxsql"
  zone_name           = azurerm_private_dns_zone.cx_sql.name
  resource_group_name = azurerm_resource_group.cx_backend.name
  ttl                 = 10
  records             = ["10.0.4.4"]
}

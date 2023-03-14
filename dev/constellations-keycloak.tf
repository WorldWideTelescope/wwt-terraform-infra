# The Keycloak service and backing database for Constellations

# The backing PostgreSQL storage database

resource "azurerm_postgresql_server" "cxsql" {
  name                = "${var.prefix}-cxsql"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name

  sku_name                     = "B_Gen5_1"
  version                      = "11"
  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = false

  public_network_access_enabled     = true # basic tier requires this (?!)
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
  infrastructure_encryption_enabled = false

  administrator_login          = "psqladmin"
  administrator_login_password = var.cxsqlAdminPassword
}

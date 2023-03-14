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

resource "azurerm_postgresql_database" "keycloak" {
  name                = "keycloak"
  resource_group_name = azurerm_resource_group.cx_backend.name
  server_name         = azurerm_postgresql_server.cxsql.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

# The Keycloak web app

resource "azurerm_linux_web_app" "keycloak" {
  name                = "${var.prefix}-keycloak"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name
  service_plan_id     = azurerm_service_plan.cx_backend.id

  app_settings = {
    "DOCKER_REGISTRY_SERVER_URL" = "https://index.docker.io/v1"
    "KEYCLOAK_FRONTEND_URL"      = "https://${var.prefix}-keycloak.azurewebsites.net/auth"
    "KEYCLOAK_USER"              = "wwtadmin"
    "KEYCLOAK_PASSWORD"          = var.cxkeycloakAdminPassword
    "DB_VENDOR"                  = "postgres"
    "DB_ADDR"                    = "${var.prefix}-cxsql.privatelink.postgres.database.azure.com"
    "DB_USER"                    = "psqladmin@${var.prefix}-cxsql"
    "DB_PASSWORD"                = var.cxsqlAdminPassword
    "JDBC_PARAMS"                = "sslmode=prefer&sslrootcert=/etc/ssl/certs/ca-bundle.crt"
    "PROXY_ADDRESS_FORWARDING"   = "true"
  }

  https_only = true

  site_config {
    always_on              = false
    ftps_state             = "Disabled"
    vnet_route_all_enabled = true

    application_stack {
      docker_image     = "jboss/keycloak"
      docker_image_tag = "latest"
    }
  }

  virtual_network_subnet_id = azurerm_subnet.cx_backend_keycloak.id
}

resource "azurerm_subnet" "cx_backend_keycloak" {
  name                 = "${var.prefix}-cxbeKcSubnet"
  resource_group_name  = azurerm_resource_group.cx_backend.name
  virtual_network_name = azurerm_virtual_network.cx_backend.name
  address_prefixes     = ["10.0.6.0/24"]

  delegation {
    name = "dlg-appServices"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
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
    "creator" = "created by private endpoint wwtdev-cxbeSqlEndpoint with resource guid 53423fed-aee8-47a2-8433-e631e7570adb"
  }
}

resource "azurerm_private_dns_a_record" "cx_backend_sql_loc" {
  name                = "${var.prefix}-cxsql-${azurerm_resource_group.cx_backend.location}"
  zone_name           = azurerm_private_dns_zone.cx_sql.name
  resource_group_name = azurerm_resource_group.cx_backend.name
  ttl                 = 10
  records             = ["10.0.4.5"]
}

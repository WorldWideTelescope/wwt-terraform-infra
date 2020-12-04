provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
}

# For the time being, you can't mix Windows and Linux App Service Plans
# in the same resource group, so we need to use a second group:
resource "azurerm_resource_group" "linux" {
  name     = "${var.prefix}-linux-resources"
  location = var.location
}

# Uncomment if using data tier tied to this script. This is *not*
# the case for WWT production.
#
#resource "azurerm_storage_account" "datatier" {
#  name                     = "${var.prefix}storage"
#  resource_group_name      = azurerm_resource_group.main.name
#  location                 = azurerm_resource_group.main.location
#  account_tier             = "Standard"
#  account_replication_type = "LRS"
#}
#
#resource "azurerm_role_assignment" "appservice_storage" {
#  scope                = azurerm_storage_account.datatier.id
#  role_definition_name = "Storage Blob Data Reader"
#  principal_id         = azurerm_app_service.wwt.identity.0.principal_id
#}

resource "azurerm_key_vault" "wwt" {
  name                        = "${var.prefix}kv"
  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled         = true
  purge_protection_enabled    = false

  sku_name = "standard"
}

data "azurerm_client_config" "current" {
}

# Note: this plan is called just "wwt" but it is now specifically for the
# Windows-based Communities service.
resource "azurerm_app_service_plan" "wwt" {
  name                = "${var.prefix}-app-service-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service_plan" "data" {
  name                = "${var.prefix}-data-plan"
  location            = azurerm_resource_group.linux.location
  resource_group_name = azurerm_resource_group.linux.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_redis_cache" "wwt" {
  name                = "${var.prefix}-cache"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = 2
  family              = "C"
  sku_name            = "Basic"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
  }
}

resource "azurerm_key_vault_secret" "redis" {
  name         = "RedisConnectionString"
  value        = azurerm_redis_cache.wwt.primary_connection_string
  key_vault_id = azurerm_key_vault.wwt.id

  tags = {
    environment = "Production"
  }
}

resource "azurerm_application_insights" "wwt" {
  name                = "${var.prefix}insights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
}

# Note: this service is called just "wwt" but it is now specifically for the
# Windows-based Communities service.
resource "azurerm_app_service" "wwt" {
  name                = "${var.prefix}-app-service"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  app_service_plan_id = azurerm_app_service_plan.wwt.id

  site_config {
    always_on = true
    default_documents = ["hostingstart.html"]
    dotnet_framework_version = "v4.0"
  }

  app_settings = {
    "UseAzurePlateFiles" = "true"
    "UseCaching" = "true"
    #"AzurePlateFileStorageAccount" = azurerm_storage_account.datatier.primary_blob_endpoint
    "KeyVaultName" = azurerm_key_vault.wwt.name
    "SlidingExpiration" = "30.00:00:00" # default to 30 days to keep cached items
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.wwt.instrumentation_key
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_app_service" "data" {
  name                = "${var.prefix}-data-app"
  location            = azurerm_resource_group.linux.location
  resource_group_name = azurerm_resource_group.linux.name
  app_service_plan_id = azurerm_app_service_plan.data.id

  site_config {
    app_command_line = ""
    linux_fx_version = "DOCKER|aasworldwidetelescope/core-data:latest"
  }

  app_settings = {
    "UseAzurePlateFiles" = "true"
    "UseCaching" = "true"
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "KeyVaultName" = azurerm_key_vault.wwt.name
    "SlidingExpiration" = "30.00:00:00" # default to 30 days to keep cached items
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.wwt.instrumentation_key
    "DOCKER_REGISTRY_SERVER_URL" = "https://index.docker.io"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Give the app services access to KeyVault via Managed Identity

# Note: this policy is called just "appservice" but it is now specifically for
# the Windows-based Communities service.
resource "azurerm_key_vault_access_policy" "appservice" {
  key_vault_id            = azurerm_key_vault.wwt.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = azurerm_app_service.wwt.identity.0.principal_id
  secret_permissions      = ["get", "list"]
}

resource "azurerm_key_vault_access_policy" "data_appservice" {
  key_vault_id            = azurerm_key_vault.wwt.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = azurerm_app_service.data.identity.0.principal_id
  secret_permissions      = ["get", "list"]
}

resource "azurerm_key_vault_access_policy" "user" {
  key_vault_id            = azurerm_key_vault.wwt.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = data.azurerm_client_config.current.object_id
  secret_permissions      = ["get", "set", "list"]
}
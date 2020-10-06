provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
}

resource "azurerm_storage_account" "datatier" {
  name                     = "${var.prefix}storage"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

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

resource "azurerm_app_service_plan" "wwt" {
  name                = "${var.prefix}-app-service-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "wwt" {
  name                = "${var.prefix}-app-service"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  app_service_plan_id = azurerm_app_service_plan.wwt.id

  site_config {
    dotnet_framework_version = "v4.0"
  }
  
  app_settings = {
    "UseAzurePlateFiles" = "true"
    #"AzurePlateFileStorageAccount" = azurerm_storage_account.datatier.primary_blob_endpoint
    "KeyVaultName" = azurerm_key_vault.wwt.name
  }

  identity {
    type = "SystemAssigned"
  }
}

# Give the app service roles
resource "azurerm_key_vault_access_policy" "appservice" {
  key_vault_id            = azurerm_key_vault.wwt.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = azurerm_app_service.wwt.identity.0.principal_id
  secret_permissions      = ["get", "list"]
}

resource "azurerm_role_assignment" "appservice_storage" {
  scope                = azurerm_storage_account.datatier.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_app_service.wwt.identity.0.principal_id
}
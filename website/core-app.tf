# The core WWT web apps.

# Main resource group. For now, all of the resources in this file can sensibly
# share the same lifecycle, so it makes sense to put them all into one big
# resource group.
resource "azurerm_resource_group" "main" {
  name     = "${var.oldPrefix}-resources"
  location = var.location
}

# ... except that for the time being, you can't mix Windows and Linux App
# Service Plans in the same resource group, so we need to use a second group:
resource "azurerm_resource_group" "linux" {
  name     = "${var.oldPrefix}-linux-resources"
  location = var.location
}

# Uncomment if using data tier tied to this script. This is *not*
# the case for WWT production. The data tier should have a different lifecycle
# than the apps (namely it should never ever go away!)
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

# The Key Vault for secrets and app configuration.

resource "azurerm_key_vault" "wwt" {
  name                        = "${var.oldPrefix}kv"
  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled         = true
  purge_protection_enabled    = false

  sku_name = "standard"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_access_policy" "user" {
  key_vault_id            = azurerm_key_vault.wwt.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = data.azurerm_client_config.current.object_id
  secret_permissions      = ["get", "set", "list"]
}

# SQL databases powering some of the core app functionality.

resource "azurerm_sql_database" "tours" {
  name                = "WWTTours"
  resource_group_name = azurerm_resource_group.permanent_data.name
  location            = azurerm_resource_group.permanent_data.location
  server_name         = azurerm_sql_server.permanent_data_wwtcore_db_server.name

  lifecycle {
    prevent_destroy = true
  }
}

# The Redis cache layer.

resource "azurerm_redis_cache" "wwt" {
  name                = "${var.oldPrefix}-cache"
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

# The Application Insights APM layer.

resource "azurerm_application_insights" "wwt" {
  name                = "${var.oldPrefix}insights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
}

# App service plan for the Linux-based apps. This includes the
# core data services.

resource "azurerm_app_service_plan" "data" {
  name                = "${var.oldPrefix}-data-plan"
  location            = azurerm_resource_group.linux.location
  resource_group_name = azurerm_resource_group.linux.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

# TODO: possibly add mirror rules that look for under-utilization of CPU, etc.,
# and scale down the app as needed.
#
# Also TODO: I don't have a good sense of what a good referene value for the
# HTTP queue length is, thus far.
#
# For a list of app service plan metrics, see:
#
# https://docs.microsoft.com/en-us/azure/azure-monitor/platform/metrics-supported#microsoftwebserverfarms
resource "azurerm_monitor_autoscale_setting" "data" {
  name                = "${var.oldPrefix}-data-autoscaling"
  location            = azurerm_resource_group.linux.location
  resource_group_name = azurerm_resource_group.linux.name
  target_resource_id  = azurerm_app_service_plan.data.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    # Scale up if average CPU pecentage is >=75% for 5 minutes or more
    rule {
      metric_trigger {
        metric_name = "CpuPercentage"
        metric_resource_id = azurerm_app_service_plan.data.id
        statistic = "Average"
        time_grain = "PT1M"
        time_aggregation = "Average"
        time_window = "PT5M"
        operator = "GreaterThanOrEqual"
        threshold = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT15M"
      }
    }

    # Scale up if average memory pecentage is >=75% for 5 minutes or more
    rule {
      metric_trigger {
        metric_name = "MemoryPercentage"
        metric_resource_id = azurerm_app_service_plan.data.id
        statistic = "Average"
        time_grain = "PT1M"
        time_aggregation = "Average"
        time_window = "PT5M"
        operator = "GreaterThanOrEqual"
        threshold = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT15M"
      }
    }

    # Scale up if average HTTP queue length is >10 for 5 minutes or more
    rule {
      metric_trigger {
        metric_name = "HttpQueueLength"
        metric_resource_id = azurerm_app_service_plan.data.id
        statistic = "Average"
        time_grain = "PT1M"
        time_aggregation = "Average"
        time_window = "PT5M"
        operator = "GreaterThanOrEqual"
        threshold = 10
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT15M"
      }
    }
  }
}

# The main Linux-based data app service.
resource "azurerm_app_service" "data" {
  name                = "${var.oldPrefix}-data-app"
  location            = azurerm_resource_group.linux.location
  resource_group_name = azurerm_resource_group.linux.name
  app_service_plan_id = azurerm_app_service_plan.data.id

  site_config {
    always_on = true
    app_command_line = ""
    linux_fx_version = "DOCKER|aasworldwidetelescope/core-data:latest"
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.wwt.instrumentation_key
    "DOCKER_REGISTRY_SERVER_URL" = "https://index.docker.io"
    "KeyVaultName" = azurerm_key_vault.wwt.name
    "SlidingExpiration" = "30.00:00:00" # default to 30 days to keep cached items
    "UseAzurePlateFiles" = "true"
    "UseCaching" = "true"
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }

  identity {
    type = "SystemAssigned"
  }
}

# "stage" slot identical but not always_on. Note that most config/settings
# swap when you swap deployment slots, so this slot and production must
# be kept in sync. Fortunately the always_on setting stays put.
resource "azurerm_app_service_slot" "data_stage" {
  name                = "stage"
  location            = azurerm_resource_group.linux.location
  resource_group_name = azurerm_resource_group.linux.name
  app_service_plan_id = azurerm_app_service_plan.data.id
  app_service_name    = azurerm_app_service.data.name

  site_config {
    always_on = false
    app_command_line = ""
    linux_fx_version = "DOCKER|aasworldwidetelescope/core-data:latest"
  }

  app_settings = azurerm_app_service.data.app_settings

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault_access_policy" "data_appservice" {
  key_vault_id            = azurerm_key_vault.wwt.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = azurerm_app_service.data.identity.0.principal_id
  secret_permissions      = ["get", "list"]
}

resource "azurerm_key_vault_access_policy" "data_stage_appservice" {
  key_vault_id            = azurerm_key_vault.wwt.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = azurerm_app_service_slot.data_stage.identity.0.principal_id
  secret_permissions      = ["get", "list"]
}

# App service plan for the Windows-based app(s). At the moment this
# is only the Communities functionality.
#
# Note: for historical reasons, this plan is called just "wwt", but
# it is now not as globally relevant as that name would suggest.
resource "azurerm_app_service_plan" "wwt" {
  name                = "${var.oldPrefix}-app-service-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

# The Windows-based Communities app service.
#
# Note: for historical reasons, this plan is called just "wwt", but
# it is now not as globally relevant as that name would suggest.
resource "azurerm_app_service" "wwt" {
  name                = "${var.oldPrefix}-app-service"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  app_service_plan_id = azurerm_app_service_plan.wwt.id

  site_config {
    always_on = true
    dotnet_framework_version = "v4.0"
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.wwt.instrumentation_key
    #"AzurePlateFileStorageAccount" = azurerm_storage_account.datatier.primary_blob_endpoint
    "KeyVaultName" = azurerm_key_vault.wwt.name
    "LiveClientId" = var.liveClientId
    "LiveClientRedirectUrlMap" = var.liveClientRedirectUrlMap
    "LiveClientSecret" = var.liveClientSecret
    "SlidingExpiration" = "30.00:00:00" # default to 30 days to keep cached items
    "UseAzurePlateFiles" = "true"
    "UseCaching" = "true"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_app_service_slot" "communities_stage" {
  name                = "stage"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  app_service_plan_id = azurerm_app_service_plan.wwt.id
  app_service_name    = azurerm_app_service.wwt.name

  site_config {
    always_on = false
    dotnet_framework_version = "v4.0"
  }

  app_settings = azurerm_app_service.wwt.app_settings

  identity {
    type = "SystemAssigned"
  }
}


# Here, too, this policy is called just "appservice" but it is now specifically
# for the Windows-based Communities service.
resource "azurerm_key_vault_access_policy" "appservice" {
  key_vault_id            = azurerm_key_vault.wwt.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = azurerm_app_service.wwt.identity.0.principal_id
  secret_permissions      = ["get", "list"]
}

resource "azurerm_key_vault_access_policy" "appservice_stage" {
  key_vault_id            = azurerm_key_vault.wwt.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = azurerm_app_service_slot.communities_stage.identity.0.principal_id
  secret_permissions      = ["get", "list"]
}
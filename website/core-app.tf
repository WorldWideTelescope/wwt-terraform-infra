# The core WWT web apps.

# Main resource group. For now, all of the resources in this file can sensibly
# share the same lifecycle, so it makes sense to put them all into one big
# resource group.
resource "azurerm_resource_group" "coreapp" {
  name     = "${var.oldPrefix}-resources"
  location = var.location
}

# ... except that for the time being, you can't mix Windows and Linux App
# Service Plans in the same resource group, so we need to use a second group:
resource "azurerm_resource_group" "coreapp_linux" {
  name     = "${var.oldPrefix}-linux-resources"
  location = var.location
}

# Uncomment if using data tier tied to this script. This is *not*
# the case for WWT production. The data tier should have a different lifecycle
# than the apps (namely it should never ever go away!)
#
#resource "azurerm_storage_account" "datatier" {
#  name                     = "${var.prefix}storage"
#  resource_group_name      = azurerm_resource_group.coreapp.name
#  location                 = azurerm_resource_group.coreapp.location
#  account_tier             = "Standard"
#  account_replication_type = "LRS"
#}
#
#resource "azurerm_role_assignment" "appservice_storage" {
#  scope                = azurerm_storage_account.datatier.id
#  role_definition_name = "Storage Blob Data Reader"
#  principal_id         = azurerm_app_service.communities.identity.0.principal_id
#}

# The Key Vault for secrets and app configuration.

resource "azurerm_key_vault" "coreapp" {
  name                        = "${var.oldPrefix}kv"
  resource_group_name         = azurerm_resource_group.coreapp.name
  location                    = azurerm_resource_group.coreapp.location
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
  key_vault_id            = azurerm_key_vault.coreapp.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = data.azurerm_client_config.current.object_id
  secret_permissions      = ["get", "set", "list"]
}

# Keyvault secrets connecting the apps to the permanent data accounts

resource "azurerm_key_vault_secret" "communitystorage" {
  name         = "EarthOnlineStorage"
  value        = azurerm_storage_account.permanent_data_communities.primary_connection_string
  key_vault_id = azurerm_key_vault.coreapp.id

  tags = {
    "file-encoding" = "utf-8"
  }
}

resource "azurerm_key_vault_secret" "marsstorage" {
  name         = "MarsStorageAccount"
  value        = azurerm_storage_account.permanent_data_mars.primary_connection_string
  key_vault_id = azurerm_key_vault.coreapp.id
}

# SQL databases powering some of the core app functionality.

resource "azurerm_sql_database" "astro_objects" {
  name                = "AstroObjects"
  resource_group_name = azurerm_resource_group.permanent_data.name
  location            = azurerm_resource_group.permanent_data.location
  server_name         = azurerm_sql_server.permanent_data_wwtcore_db_server.name

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_sql_database" "layerscape" {
  name                = "Layerscape"
  resource_group_name = azurerm_resource_group.permanent_data.name
  location            = azurerm_resource_group.permanent_data.location
  server_name         = azurerm_sql_server.permanent_data_communities_db_server.name

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_sql_database" "tours" {
  name                = "WWTTours"
  resource_group_name = azurerm_resource_group.permanent_data.name
  location            = azurerm_resource_group.permanent_data.location
  server_name         = azurerm_sql_server.permanent_data_wwtcore_db_server.name

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_secret" "layerscapedb" {
  name         = "EarthOnlineEntities"
  value        = "metadata=res://*/Models.EarthOnline.csdl|res://*/Models.EarthOnline.ssdl|res://*/Models.EarthOnline.msl;provider=System.Data.SqlClient;provider connection string=\"Data Source=${azurerm_sql_server.permanent_data_communities_db_server.fully_qualified_domain_name};Initial Catalog=${azurerm_sql_database.layerscape.name};Integrated Security=False;User ID=${azurerm_sql_server.permanent_data_communities_db_server.administrator_login};Password=${var.layerscapeDbPassword};multipleactiveresultsets=True;App=EntityFramework\""
  key_vault_id = azurerm_key_vault.coreapp.id
}

resource "azurerm_key_vault_secret" "toursdb" {
  name         = "WWTToursDBConnectionString"
  value        = "Server=tcp:${azurerm_sql_server.permanent_data_wwtcore_db_server.fully_qualified_domain_name},1433;Database=${azurerm_sql_database.tours.name};User ID=${azurerm_sql_server.permanent_data_wwtcore_db_server.administrator_login}@${azurerm_sql_server.permanent_data_wwtcore_db_server.name};Password=${var.wwttoursDbPassword};Trusted_Connection=False;Encrypt=True;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.coreapp.id

  tags = {
    "file-encoding" = "utf-8"
  }
}

# The Redis cache layer.

resource "azurerm_redis_cache" "wwt" {
  name                = "${var.oldPrefix}-cache"
  location            = azurerm_resource_group.coreapp.location
  resource_group_name = azurerm_resource_group.coreapp.name
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
  key_vault_id = azurerm_key_vault.coreapp.id

  tags = {
    environment = "Production"
  }
}

# The Application Insights APM layer.

resource "azurerm_application_insights" "wwt" {
  name                = "${var.oldPrefix}insights"
  location            = azurerm_resource_group.coreapp.location
  resource_group_name = azurerm_resource_group.coreapp.name
  application_type    = "web"
}

# App service plan for the Linux-based apps. This includes the
# core data services.

resource "azurerm_app_service_plan" "data" {
  name                = "${var.oldPrefix}-data-plan"
  location            = azurerm_resource_group.coreapp_linux.location
  resource_group_name = azurerm_resource_group.coreapp_linux.name
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
  location            = azurerm_resource_group.coreapp_linux.location
  resource_group_name = azurerm_resource_group.coreapp_linux.name
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
  location            = azurerm_resource_group.coreapp_linux.location
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  app_service_plan_id = azurerm_app_service_plan.data.id

  site_config {
    always_on = true
    app_command_line = ""
    linux_fx_version = "DOCKER|aasworldwidetelescope/core-data:latest"
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.wwt.instrumentation_key
    "DOCKER_REGISTRY_SERVER_URL" = "https://index.docker.io"
    "KeyVaultName" = azurerm_key_vault.coreapp.name
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
  location            = azurerm_resource_group.coreapp_linux.location
  resource_group_name = azurerm_resource_group.coreapp_linux.name
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
  key_vault_id            = azurerm_key_vault.coreapp.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = azurerm_app_service.data.identity.0.principal_id
  secret_permissions      = ["get", "list"]
}

resource "azurerm_key_vault_access_policy" "data_stage_appservice" {
  key_vault_id            = azurerm_key_vault.coreapp.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = azurerm_app_service_slot.data_stage.identity.0.principal_id
  secret_permissions      = ["get", "list"]
}

# Separate Linux-based proxy service. This used to be implemented in the core
# apps. It's essentially standalone, but does get mixed into the /wwtweb/ URL
# hierarchy.

resource "azurerm_app_service" "core_proxy" {
  name                = "${var.prefix}-coreproxy"
  location            = azurerm_resource_group.coreapp_linux.location
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  app_service_plan_id = azurerm_app_service_plan.data.id

  site_config {
    always_on = false
    app_command_line = ""
    linux_fx_version = "DOCKER|aasworldwidetelescope/proxy:latest"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# App service for the core+misc nginx server. This mostly handles traffic to
# random worldwidetelescope.org URLs, but also handles some miscellaneous web
# traffic. The setup for those custom domains turns out to be quite tedious!

resource "azurerm_app_service" "core_nginx" {
  name                = "${var.prefix}-corenginx"
  location            = azurerm_resource_group.coreapp_linux.location
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  app_service_plan_id = azurerm_app_service_plan.data.id

  app_settings = {
    "PUBLIC_FACING_DOMAIN_NAME" = "worldwidetelescope.org"
  }

  site_config {
    always_on = false
    app_command_line = ""
    linux_fx_version = "DOCKER|aasworldwidetelescope/nginx-core:latest"
  }
}

resource "azurerm_app_service_custom_hostname_binding" "core_nginx_binder_wwtforum_org" {
  hostname            = "binder.wwt-forum.org"
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  app_service_name    = azurerm_app_service.core_nginx.name

  # These are managed through the cert binding:
  lifecycle {
    ignore_changes = [ssl_state, thumbprint]
  }
}

resource "azurerm_app_service_managed_certificate" "core_nginx_binder_wwtforum_org" {
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.core_nginx_binder_wwtforum_org.id
}

resource "azurerm_app_service_certificate_binding" "core_nginx_binder_wwtforum_org" {
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.core_nginx_binder_wwtforum_org.id
  certificate_id      = azurerm_app_service_managed_certificate.core_nginx_binder_wwtforum_org.id
  ssl_state           = "SniEnabled"
}

resource "azurerm_app_service_custom_hostname_binding" "core_nginx_forum_wwto" {
  hostname            = "forum.worldwidetelescope.org"
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  app_service_name    = azurerm_app_service.core_nginx.name

  lifecycle {
    ignore_changes = [ssl_state, thumbprint]
  }
}

resource "azurerm_app_service_managed_certificate" "core_nginx_forum_wwto" {
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.core_nginx_forum_wwto.id
}

resource "azurerm_app_service_certificate_binding" "core_nginx_forum_wwto" {
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.core_nginx_forum_wwto.id
  certificate_id      = azurerm_app_service_managed_certificate.core_nginx_forum_wwto.id
  ssl_state           = "SniEnabled"
}

resource "azurerm_app_service_custom_hostname_binding" "core_nginx_forums_wwto" {
  hostname            = "forums.worldwidetelescope.org"
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  app_service_name    = azurerm_app_service.core_nginx.name

  lifecycle {
    ignore_changes = [ssl_state, thumbprint]
  }
}

resource "azurerm_app_service_managed_certificate" "core_nginx_forums_wwto" {
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.core_nginx_forums_wwto.id
}

resource "azurerm_app_service_certificate_binding" "core_nginx_forums_wwto" {
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.core_nginx_forums_wwto.id
  certificate_id      = azurerm_app_service_managed_certificate.core_nginx_forums_wwto.id
  ssl_state           = "SniEnabled"
}

# TODO/FIXME: managed certs can't be used for root domains, so we have this set
# up to get a cert from our LetsEncrypt keyvault setup. However, Terraform seems
# to have issues with a keyvault-based custom cert setup here --
# `azurerm_app_service_certificate.key_vault_secret_id` exists but Terraform
# won't parse a reference to the generic secret, and `az webapp config ssl show`
# reports a different data structure. So for now we skip automated SSL
# configuration for this particular utility domain. I've got it set up through
# the Portal UI manually.
resource "azurerm_app_service_custom_hostname_binding" "core_nginx_wwtassets_org" {
  hostname            = "wwtassets.org"
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  app_service_name    = azurerm_app_service.core_nginx.name

  lifecycle {
    ignore_changes = [ssl_state, thumbprint]
  }
}

# App service plan for the Windows-based app(s). At the moment this
# is only the Communities functionality.
resource "azurerm_app_service_plan" "communities" {
  name                = "${var.oldPrefix}-app-service-plan"
  location            = azurerm_resource_group.coreapp.location
  resource_group_name = azurerm_resource_group.coreapp.name

  sku {
    tier = "Standard"
    size = "S1"
  }
}

# The Windows-based Communities app service.
resource "azurerm_app_service" "communities" {
  name                = "${var.oldPrefix}-app-service"
  location            = azurerm_resource_group.coreapp.location
  resource_group_name = azurerm_resource_group.coreapp.name
  app_service_plan_id = azurerm_app_service_plan.communities.id

  site_config {
    always_on = true
    dotnet_framework_version = "v4.0"
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.wwt.instrumentation_key
    #"AzurePlateFileStorageAccount" = azurerm_storage_account.datatier.primary_blob_endpoint
    "KeyVaultName" = azurerm_key_vault.coreapp.name
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
  location            = azurerm_resource_group.coreapp.location
  resource_group_name = azurerm_resource_group.coreapp.name
  app_service_plan_id = azurerm_app_service_plan.communities.id
  app_service_name    = azurerm_app_service.communities.name

  site_config {
    always_on = false
    dotnet_framework_version = "v4.0"
  }

  app_settings = azurerm_app_service.communities.app_settings

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault_access_policy" "communities_app" {
  key_vault_id            = azurerm_key_vault.coreapp.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = azurerm_app_service.communities.identity.0.principal_id
  secret_permissions      = ["get", "list"]
}

resource "azurerm_key_vault_access_policy" "communities_app_stage" {
  key_vault_id            = azurerm_key_vault.coreapp.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = azurerm_app_service_slot.communities_stage.identity.0.principal_id
  secret_permissions      = ["get", "list"]
}
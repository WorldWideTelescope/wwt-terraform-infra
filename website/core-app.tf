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
#  principal_id         = azurerm_windows_web_app.communities.identity.0.principal_id
#}

# The Key Vault for secrets and app configuration. The web app's
# configurationbuilder setup scans this keyvault for configuration keys, so its
# contents should be limited to things specific to the app. For manageability we
# should also try to make it so that the keyvault contains only secrets, while
# the app_settings in this file are used for non-secret values.

resource "azurerm_key_vault" "coreapp" {
  name                        = "${var.oldPrefix}kv"
  resource_group_name         = azurerm_resource_group.coreapp.name
  location                    = azurerm_resource_group.coreapp.location
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled    = false

  sku_name = "standard"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_access_policy" "user" {
  key_vault_id       = azurerm_key_vault.coreapp.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "Set", "List", "Delete"]
}

# Keyvault secrets connecting the apps to the permanent data accounts

resource "azurerm_key_vault_secret" "corestorage" {
  name         = "AzurePlateFileStorageAccount"
  value        = azurerm_storage_account.permanent_data_core.primary_connection_string
  key_vault_id = azurerm_key_vault.coreapp.id
  content_type = "text/plain"
}

resource "azurerm_key_vault_secret" "communitystorage" {
  name         = "EarthOnlineStorage"
  value        = azurerm_storage_account.permanent_data_communities.primary_connection_string
  key_vault_id = azurerm_key_vault.coreapp.id
  content_type = "text/plain"

  tags = {
    "file-encoding" = "utf-8"
  }
}

resource "azurerm_key_vault_secret" "marsstorage" {
  name         = "MarsStorageAccount"
  value        = azurerm_storage_account.permanent_data_mars.primary_connection_string
  key_vault_id = azurerm_key_vault.coreapp.id
  content_type = "text/plain"
}

resource "azurerm_key_vault_secret" "wwtwebstorage" {
  // This is only used for a couple of esoteric API calls ... would be nice to
  // be able to get rid of it.
  name         = "WWTWebBlobs"
  value        = azurerm_storage_account.permanent_data_wwtweb.primary_connection_string
  key_vault_id = azurerm_key_vault.coreapp.id
  content_type = "text/plain"

  tags = {
    "file-encoding" = "utf-8"
  }
}

# SQL databases powering some of the core app functionality.

resource "azurerm_mssql_database" "astro_objects" {
  name      = "AstroObjects"
  server_id = azurerm_mssql_server.permanent_data_wwtcore_db_server.id
  sku_name  = "S0"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_mssql_database" "layerscape" {
  name      = "Layerscape"
  server_id = azurerm_mssql_server.permanent_data_communities_db_server.id
  sku_name  = "S0"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_mssql_database" "tours" {
  name      = "WWTTours"
  server_id = azurerm_mssql_server.permanent_data_wwtcore_db_server.id
  sku_name  = "S0"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault_secret" "layerscapedb" {
  name         = "EarthOnlineEntities"
  value        = "metadata=res://*/Models.EarthOnline.csdl|res://*/Models.EarthOnline.ssdl|res://*/Models.EarthOnline.msl;provider=System.Data.SqlClient;provider connection string=\"Data Source=${azurerm_mssql_server.permanent_data_communities_db_server.fully_qualified_domain_name};Initial Catalog=${azurerm_mssql_database.layerscape.name};Integrated Security=False;User ID=${azurerm_mssql_server.permanent_data_communities_db_server.administrator_login};Password=${var.layerscapeDbPassword};multipleactiveresultsets=True;App=EntityFramework\""
  key_vault_id = azurerm_key_vault.coreapp.id
  content_type = "text/plain"
}

resource "azurerm_key_vault_secret" "toursdb" {
  name         = "WWTToursDBConnectionString"
  value        = "Server=tcp:${azurerm_mssql_server.permanent_data_wwtcore_db_server.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.tours.name};User ID=${azurerm_mssql_server.permanent_data_wwtcore_db_server.administrator_login}@${azurerm_mssql_server.permanent_data_wwtcore_db_server.name};Password=${var.wwttoursDbPassword};Trusted_Connection=False;Encrypt=True;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.coreapp.id
  content_type = "text/plain"

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
  content_type = "text/plain"

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

resource "azurerm_service_plan" "data" {
  name                = "${var.oldPrefix}-data-plan"
  location            = azurerm_resource_group.coreapp_linux.location
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  os_type             = "Linux"
  sku_name            = "S1"
}

# Autoscale rules. Note that if you don't have any scale-down rules, your number
# of instances will only ever go up. Furthermore, the autoscaler has naive logic
# to prevent "flapping", i.e. cases where the number of instances continually
# oscillates up and down. Specifically, if you've got rules associated with some
# metric, the autoscaler will assume that that metric gets divided evenly among
# your instances, and it won't apply a scaling rule if it thinks the change will
# apply the rule in the reverse direction. I had to remove scaling rules based
# on memory percentage since this logic fails if your metric has a "baseline"
# usage per-instance that doesn't scale with demand. Basically you should only
# add scaling rules for metrics that will go to zero if no requests are coming
# in.
#
# Also TODO: I don't have a good sense of what a good reference value for the
# HTTP queue length is, thus far.
#
# For a list of app service plan metrics, see:
#
# https://docs.microsoft.com/en-us/azure/azure-monitor/platform/metrics-supported#microsoftwebserverfarms
resource "azurerm_monitor_autoscale_setting" "data" {
  name                = "${var.oldPrefix}-data-autoscaling"
  location            = azurerm_resource_group.coreapp_linux.location
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  target_resource_id  = azurerm_service_plan.data.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    # Scale up if average CPU pecentage is >=75% for 5 minutes or more. Down
    # if <=50%.
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.data.id
        statistic          = "Average"
        time_grain         = "PT1M"
        time_aggregation   = "Average"
        time_window        = "PT5M"
        operator           = "GreaterThanOrEqual"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT15M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.data.id
        statistic          = "Average"
        time_grain         = "PT1M"
        time_aggregation   = "Average"
        time_window        = "PT5M"
        operator           = "LessThanOrEqual"
        threshold          = 50
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT15M"
      }
    }

    # Scale up if average HTTP queue length is >=10 for 5 minutes or more.
    # Down if <=2.
    rule {
      metric_trigger {
        metric_name        = "HttpQueueLength"
        metric_resource_id = azurerm_service_plan.data.id
        statistic          = "Average"
        time_grain         = "PT1M"
        time_aggregation   = "Average"
        time_window        = "PT5M"
        operator           = "GreaterThanOrEqual"
        threshold          = 10
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT15M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "HttpQueueLength"
        metric_resource_id = azurerm_service_plan.data.id
        statistic          = "Average"
        time_grain         = "PT1M"
        time_aggregation   = "Average"
        time_window        = "PT5M"
        operator           = "LessThanOrEqual"
        threshold          = 2
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT15M"
      }
    }
  }
}

# The main Linux-based data app service.
resource "azurerm_linux_web_app" "data" {
  name                = "${var.oldPrefix}-data-app"
  location            = azurerm_resource_group.coreapp_linux.location
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  service_plan_id     = azurerm_service_plan.data.id
  # Docker container: aasworldwidetelescope/core-data:latest

  site_config {
    always_on        = true
    app_command_line = ""

    # Added 2022 Sep to match ground truth:
    ftps_state              = "AllAllowed"
    scm_minimum_tls_version = "1.0"
    use_32_bit_worker       = false
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"      = azurerm_application_insights.wwt.instrumentation_key
    "DOCKER_REGISTRY_SERVER_URL"          = "https://index.docker.io"
    "KeyVaultName"                        = azurerm_key_vault.coreapp.name
    "SlidingExpiration"                   = "30.00:00:00" # default to 30 days to keep cached items
    "UseAzurePlateFiles"                  = "true"
    "UseCaching"                          = "true"
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }

  identity {
    type = "SystemAssigned"
  }
}

# "stage" slot identical but not always_on. Note that most config/settings
# swap when you swap deployment slots, so this slot and production must
# be kept in sync. Fortunately the always_on setting stays put.
resource "azurerm_linux_web_app_slot" "data_stage" {
  name           = "stage"
  app_service_id = azurerm_linux_web_app.data.id
  # Docker container: aasworldwidetelescope/core-data:latest

  site_config {
    always_on        = false
    app_command_line = ""

    # Added 2022 Sep to match ground truth:
    ftps_state              = "AllAllowed"
    scm_minimum_tls_version = "1.0"
    use_32_bit_worker       = false
  }

  app_settings = azurerm_linux_web_app.data.app_settings

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault_access_policy" "data_appservice" {
  key_vault_id       = azurerm_key_vault.coreapp.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_linux_web_app.data.identity.0.principal_id
  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_access_policy" "data_stage_appservice" {
  key_vault_id       = azurerm_key_vault.coreapp.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_linux_web_app_slot.data_stage.identity.0.principal_id
  secret_permissions = ["Get", "List"]
}

# Separate Linux-based proxy service. This used to be implemented in the core
# apps. It's essentially standalone, but does get mixed into the /wwtweb/ URL
# hierarchy.

resource "azurerm_linux_web_app" "core_proxy" {
  name                = "${var.prefix}-coreproxy"
  location            = azurerm_resource_group.coreapp_linux.location
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  service_plan_id     = azurerm_service_plan.data.id
  # Docker container: aasworldwidetelescope/proxy:latest"

  site_config {
    always_on        = false
    app_command_line = ""

    # Added 2022 Sep to match ground truth:
    ftps_state              = "AllAllowed"
    scm_minimum_tls_version = "1.0"
    use_32_bit_worker       = false
  }

  logs {
    detailed_error_messages = false
    failed_request_tracing  = false

    http_logs {
      file_system {
        retention_in_days = 14
        retention_in_mb   = 35
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# App service for the core+misc nginx server. This mostly handles traffic to
# random worldwidetelescope.org URLs, but also handles some miscellaneous web
# traffic. The setup for those custom domains turns out to be quite tedious!

resource "azurerm_linux_web_app" "core_nginx" {
  name                = "${var.prefix}-corenginx"
  location            = azurerm_resource_group.coreapp_linux.location
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  service_plan_id     = azurerm_service_plan.data.id
  # Docker container: aasworldwidetelescope/nginx-core:latest

  app_settings = {
    "PUBLIC_FACING_DOMAIN_NAME"  = "worldwidetelescope.org"
    "DOCKER_ENABLE_CI"           = "true"
    "DOCKER_REGISTRY_SERVER_URL" = "https://index.docker.io/v1"
  }

  site_config {
    always_on        = false
    app_command_line = ""

    # Added 2022 Sep to match ground truth:
    ftps_state              = "AllAllowed"
    scm_minimum_tls_version = "1.0"
    use_32_bit_worker       = false
  }
}

resource "azurerm_app_service_custom_hostname_binding" "core_nginx_binder_wwtforum_org" {
  hostname            = "binder.wwt-forum.org"
  resource_group_name = azurerm_resource_group.coreapp_linux.name
  app_service_name    = azurerm_linux_web_app.core_nginx.name

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
  app_service_name    = azurerm_linux_web_app.core_nginx.name

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
  app_service_name    = azurerm_linux_web_app.core_nginx.name

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
  app_service_name    = azurerm_linux_web_app.core_nginx.name

  lifecycle {
    ignore_changes = [ssl_state, thumbprint]
  }
}

# App service plan for the Windows-based app(s). At the moment this
# is only the Communities functionality.
resource "azurerm_service_plan" "communities" {
  name                = "${var.oldPrefix}-app-service-plan"
  location            = azurerm_resource_group.coreapp.location
  resource_group_name = azurerm_resource_group.coreapp.name
  os_type             = "Windows"
  sku_name            = "S1"
}

# The Windows-based Communities app service.
resource "azurerm_windows_web_app" "communities" {
  name                    = "${var.oldPrefix}-app-service"
  location                = azurerm_resource_group.coreapp.location
  resource_group_name     = azurerm_resource_group.coreapp.name
  service_plan_id         = azurerm_service_plan.communities.id
  client_certificate_mode = "Required"

  site_config {
    always_on = true

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v4.0"
    }

    # Added to reflect ground truth, 2022-Sep:
    ftps_state              = "AllAllowed"
    scm_minimum_tls_version = "1.0"
    use_32_bit_worker       = false
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.wwt.instrumentation_key
    #"AzurePlateFileStorageAccount" = azurerm_storage_account.datatier.primary_blob_endpoint
    "KeyVaultName"             = azurerm_key_vault.coreapp.name
    "LiveClientId"             = var.liveClientId
    "LiveClientRedirectUrlMap" = var.liveClientRedirectUrlMap
    "LiveClientSecret"         = var.liveClientSecret
    "SlidingExpiration"        = "30.00:00:00" # default to 30 days to keep cached items
    "UseAzurePlateFiles"       = "true"
    "UseCaching"               = "true"
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      azure_blob_storage {
        retention_in_days = 180
        sas_url           = var.appLogSasUrl
      }
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Added to reflect ground truth, 2022-Sep:
  sticky_settings {
    app_setting_names = [
      "APPINSIGHTS_PROFILERFEATURE_VERSION",
      "APPINSIGHTS_SNAPSHOTFEATURE_VERSION",
      "APPLICATIONINSIGHTS_CONNECTION_STRING ",
      "ApplicationInsightsAgent_EXTENSION_VERSION",
      "DiagnosticServices_EXTENSION_VERSION",
      "InstrumentationEngine_EXTENSION_VERSION",
      "LiveClientRedirectUrl",
      "SnapshotDebugger_EXTENSION_VERSION",
      "XDT_MicrosoftApplicationInsights_BaseExtensions",
      "XDT_MicrosoftApplicationInsights_Mode",
      "XDT_MicrosoftApplicationInsights_PreemptSdk",
    ]
  }
}

resource "azurerm_windows_web_app_slot" "communities_stage" {
  name           = "stage"
  app_service_id = azurerm_windows_web_app.communities.id

  site_config {
    always_on = false

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v4.0"
    }

    # Added to reflect ground truth, 2022-Sep:
    ftps_state              = "AllAllowed"
    scm_minimum_tls_version = "1.0"
    virtual_application {
      physical_path = "site\\wwwroot"
      preload       = false
      virtual_path  = "/"
    }
  }

  app_settings = azurerm_windows_web_app.communities.app_settings

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault_access_policy" "communities_app" {
  key_vault_id       = azurerm_key_vault.coreapp.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_windows_web_app.communities.identity.0.principal_id
  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_access_policy" "communities_app_stage" {
  key_vault_id       = azurerm_key_vault.coreapp.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_windows_web_app_slot.communities_stage.identity.0.principal_id
  secret_permissions = ["Get", "List"]
}

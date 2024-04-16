# Keyvault-acmebot Subsystem - managing SSL certificates
#
# The problem is that there is no Azure-managed way to set up and renew an HTTPS
# certificate for an Azure Application Gateway frontend, and that's what we use
# to direct our HTTP traffic. Given that, the tempting approach is to use [Let's
# Encrypt][le]. But how?
#
# [le]: https://letsencrypt.org/
#
#
# ## Implementation
#
# A project called [keyvault-acmebot][kvab] integrates the protocol that
# underlies [Let's Encrypt][le], [ACME], into an Azure environment, in a way
# that can be integrated with the Azure Application Gateway system.
#
# [kvab]: https://github.com/shibayan/keyvault-acmebot [ACME]:
# https://www.rfc-editor.org/rfc/rfc8555
#
# When we first installed this, it wasn't based on Terraform, but we've switch
# to a Terraform module now.
#
#
# ## Management
#
# [keyvault-acmebot][kvab] actually comes with a nice UI. You can manage the
# certs through:
#
# ```
# https://func-wwtprod-kvacmebot.azurewebsites.net/dashboard
# ```
#
# (You have to login through the Azure identity framework so it is not a big
# deal if people know this URL.)
#
#
# ## New Certificate
#
# To set up the app to manage a new DNS Zone, it has to have the right role
# assignments, as per [the wiki][1]. Might also need to reconfigure and/or
# restart the function app host to get it to see a new zone.
#
# [1]: https://github.com/shibayan/keyvault-acmebot/wiki/DNS-Provider-Configuration#azure-dns

module "keyvault_acmebot" {
  source  = "shibayan/keyvault-acmebot/azurerm"
  version = "~> 3.0"

  app_base_name       = "${var.prefix}-kvacmebot"
  resource_group_name = azurerm_resource_group.kvacmebot.name
  location            = var.location
  mail_address        = "wwt@aas.org"
  vault_uri           = azurerm_key_vault.ssl.vault_uri

  azure_dns = {
    subscription_id = data.azurerm_client_config.current.subscription_id
  }

  additional_app_settings = {
    "WEBSITE_AUTH_AAD_ALLOWED_TENANTS" = data.azurerm_client_config.current.tenant_id
  }

  auth_settings = {
    enabled = true
    active_directory = {
      client_id            = var.keyvaultAcmebotAuthClientId
      client_secret        = "unused"
      tenant_auth_endpoint = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/v2.0"
    }
  }
}

resource "azurerm_resource_group" "kvacmebot" {
  name     = "${var.prefix}-kvacmebot"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_key_vault" "ssl" {
  name                        = var.legacyNameSSLVault
  resource_group_name         = azurerm_resource_group.web_frontend_legacy.name
  location                    = azurerm_resource_group.web_frontend_legacy.location
  enabled_for_disk_encryption = false
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled    = false

  sku_name = "standard"

  lifecycle {
    prevent_destroy = true
  }
}

# TODO: could define azurerm_key_vault_access_policy entries but we have
# preexisting ones that will be annoying to import.

resource "azurerm_role_assignment" "kvacmebot_flagship" {
  scope                = replace(azurerm_dns_zone.flagship.id, "dnsZones", "dnszones")
  role_definition_name = "DNS Zone Contributor"
  principal_id         = module.keyvault_acmebot.principal_id
}

resource "azurerm_role_assignment" "kvacmebot_assets" {
  scope                = replace(azurerm_dns_zone.assets.id, "dnsZones", "dnszones")
  role_definition_name = "DNS Zone Contributor"
  principal_id         = module.keyvault_acmebot.principal_id
}

# TODO: wwt-forum DNS zone. Use `az role assignment list --scope` to get the ID
# for terraform import.

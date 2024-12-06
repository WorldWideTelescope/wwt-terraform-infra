// Fundamentals

variable "prefix" {
  description = "A prefix label, like wwtdev, for uniquifying public resource names"
}

variable "location" {
  description = "The location where resources will be created"
}

variable "oldPrefix" {
  description = "A different, inferior public resource prefix label used to set up the production system"
}

variable "tld" {
  description = "The top-level domain of the website"
}

// Constellations stuff

variable "cxsqlAdminPassword" {
  // Sync with LastPass. Arbitrary, not connected to any external services.
  description = "The administrator password for the Constellations PostgreSQL database"
  sensitive   = true
}

variable "cxkeycloakAdminPassword" {
  // Sync with LastPass. Arbitrary, not connected to any external services.
  description = "The administrator password for the Constellations Keycloak server"
  sensitive   = true
}

variable "googleAnalyticsTag" {
  description = "The Google Analytics tag for frontend telemetry (of the form G-XXXXXXXXXX)"
}

variable "sessionSecrets" {
  // Sync with LastPass. Arbitrary, not connected to any external services.
  description = "Space-separated list of secrets for backend session management"
  sensitive   = true
}

variable "superuserAccountId" {
  # I can't see how it would be a problem if this value leaked somehow, but just
  # to be safe we mark it as sensitive.
  description = "The account ID of an account with special admin privileges"
  sensitive   = true
}

// Names for "legacy" resources -- preexisting assets that we have imported into
// Terraform.

variable "legacyNameCommunitiesDBServer" {
  description = "The name to use for the 'legacy' SQL server with the Layerscape database"
}

variable "legacyNameCommunitiesStorage" {
  description = "The name to use for the 'legacy' storage account equivalent to 'wwtcommunity' in production"
}

variable "legacyNameCoreStorage" {
  description = "The 'legacy name' of the WWT core-data storage account"
}

variable "legacyNameFrontendGroup" {
  description = "The name to use for the 'legacy' web frontend resource group"
}

variable "legacyNameMarsStorage" {
  description = "The 'legacy name' of the Mars data storage account"
}

variable "legacyNameSSLVault" {
  description = "The 'legacy name' of the WWT SSL certificate keyvault"
}

variable "legacyNameWwtcoreDBServer" {
  description = "The name to use for the 'legacy' SQL server with the AstroObjects and WWTTours databases"
}

variable "legacyNameWwtwebStorage" {
  description = "The name to use for the 'legacy' storage account equivalent to 'wwtweb' in production"
}

variable "legacyNameWwtwebstaticStorage" {
  description = "The name to use for the 'legacy' storage account equivalent to 'wwtwebstatic' in production"
}

variable "legacyNameLogAnalyticsWorkspace" {
  description = "The name to use for the log analytics workspace"
}

variable "legacyNameLogAnalyticsGroup" {
  description = "The name to use for the log analytics resource group"
}

// Other configuration.

variable "liveClientId" {
  description = "The ID of the Microsoft Live OAuth app"
}

variable "liveClientRedirectUrlMap" {
  description = "A map from server hostname to OAuth redirectURL to use"
}

variable "liveClientSecret" {
  description = "The OAuth app secret"
  sensitive   = true
}

variable "communitiesDbAdminPassword" {
  description = "The password to the communities database server admin account"
  sensitive   = true
}

variable "wwtcoreDbAdminPassword" {
  description = "The password to the wwtcore database server admin account"
  sensitive   = true
}

variable "layerscapeDbPassword" {
  description = "The password to the Layerscape database user account"
  sensitive   = true
}

variable "wwttoursDbPassword" {
  description = "The password to the WWTTours database user account"
  sensitive   = true
}

variable "appLogSasUrl" {
  description = "Azure Blob Storage SAS URL for Windows web app diagnostic logs"
  sensitive   = true
}

variable "googleSiteVerificationTag1" {
  description = "A Google site verification tag (1)"
}

variable "googleSiteVerificationTag2" {
  description = "A Google site verification tag (2)"
}

variable "keyvaultAcmebotAuthClientId" {
  // get value from: func-wwtprod-kvacmebot Function App -> Authentication -> Microsoft identity provider
  description = "The client ID for the keyvault-acmebot Active Directory connection"
}

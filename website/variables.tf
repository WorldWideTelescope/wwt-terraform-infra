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

// Names for "legacy" resources -- preexisting assets that we have imported into
// Terraform.

variable "legacyNameCommunitiesStorage" {
  description = "The name to use for the 'legacy' storage account equivalent to 'wwtcommunity' in production"
}

variable "legacyNameWwtcoreDBServer" {
  description = "The name to use for the 'legacy' database with AstroObjects and WWTTours"
}

variable "legacyNameWwtwebStorage" {
  description = "The name to use for the 'legacy' storage account equivalent to 'wwtweb' in production"
}

variable "legacyNameWwtwebstaticStorage" {
  description = "The name to use for the 'legacy' storage account equivalent to 'wwtwebstatic' in production"
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
}

variable "wwtcoreDbAdminPassword" {
  description = "The password to the wwtcore database server admin account"
}

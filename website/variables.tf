// Fundamentals

variable "prefix" {
  description = "A prefix label, like wwtdev, for uniquifying public resource names"
}

variable "location" {
  description = "The location where resources will be created"
}

// Names for "legacy" resources -- preexisting assets that we have imported into
// Terraform.

variable "legacyNameWwtweb" {
  description = "The name to use for the 'legacy' storage account equivalent to 'wwtweb' in production"
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

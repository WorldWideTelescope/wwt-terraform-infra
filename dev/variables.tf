// Our Terraform variables
//
// Ideally these would gradually become more and more aligned with the ones in
// `prod`.

variable "prefix" {
  description = "A prefix label, like wwtdev, for uniquifying public resource names"
}

variable "location" {
  description = "The location where resources will be created"
}

variable "tld" {
  description = "The top-level domain of the website"
}

variable "cxsqlAdminPassword" {
  description = "The administrator password for the Constellations PostgreSQL database"
  sensitive   = true
}

variable "cxkeycloakAdminPassword" {
  description = "The administrator password for the Constellations Keycloak server"
  sensitive   = true
}

variable "googleAnalyticsTag" {
  description = "The Google Analytics tag for frontend telemetry (of the form G-XXXXXXXXXX)"
}

variable "sessionSecrets" {
  description = "Space-separated list of secrets for backend session management"
  sensitive   = true
}

variable "tmpVaultId" {
  description = "The Azure resource ID of the keyvault to use"
}

variable "gatewaySslCertSecretId" {
  # This cert is managed outside of Terraform through keyvault-acmebot:
  description = "The Keyvault ID of the SSL certificate to use for the App Gateway frontend"
}

variable "superuserAccountId" {
  # I can't see how it would be a problem if this value leaked somehow, but just
  # to be safe we mark it as sensitive.
  description = "The account ID of an account with special admin privileges"
  sensitive   = true
}

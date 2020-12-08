variable "prefix" {
  description = "A prefix label, like wwtdev"
}

variable "location" {
  description = "The location where resources will be created"
}

variable "liveClientId" {
  description = "The ID of the Microsoft Live OAuth app"
}

variable "liveClientRedirectUrlMap" {
  description = "A map from server hostname to OAuth redirectURL to use"
}

variable "liveClientSecret" {
  description = "The OAuth app secret"
}

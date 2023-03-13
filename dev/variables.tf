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

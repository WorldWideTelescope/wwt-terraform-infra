variable "prefix" {
    description = "A prefix label, like wwtdev"
}

variable "location" {
 description = "The location where resources will be created"
}

variable "admin_username" {
   description = "Default username for admin account"
}

variable "admin_password" {
   description = "The password for the default admin user"
}

variable "vm_sku" {
   description = "Default VM size"
   default = "Standard_A2"
}

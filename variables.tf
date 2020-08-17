variable "prefix" {
    description = "A prefix label, like wwtdev"
}

variable "location" {
 description = "The location where resources will be created"
}

variable "tags" {
 description = "A map of the tags to use for the resources that are deployed"
 type        = map(string)

 default = {
   environment = "dev"
 }
}

variable "resource_group_name" {
 description = "The name of the resource group in which the resources will be created"
}

variable "admin_user" {
   description = "User name to use as the admin account on the VMs that will be part of the VM Scale Set"
   default     = "wwtvmuser"
}

variable "admin_password" {
   description = "Default password for admin account"
}
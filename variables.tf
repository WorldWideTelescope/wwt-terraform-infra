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

variable "vm_sku" {
   description = "The VM size to use for the VMSS, defaults to dual core w/4gb memory - low perf tier"
   default = "Standard_A2"
}

variable "vm_instance_count" {
   description = "How many instances to deploy to the VMSS"
   default = 2
}
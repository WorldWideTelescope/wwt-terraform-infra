# WWT Azure resource descriptions. Terraform docs:
#
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
#
# Most of the action is in other files.

provider "azurerm" {
  features {}
}

# Store state in WWT's Azure blob storage:

terraform {
  backend "azurerm" {
    resource_group_name  = "devops-support"
    storage_account_name = "wwtdevops"
    container_name       = "terraform-state"
    key                  = "prod.terraform.tfstate"
  }
}

# Base configuration properties of the active AzureRM setup:

data "azurerm_client_config" "current" {
}
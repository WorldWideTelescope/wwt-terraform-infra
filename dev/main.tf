# WWT Azure resource descriptions for the development environment. Terraform docs:
#
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
#
# This development environment is only a partial approximation of the production
# environment. Ideally, over time the two would become more and more similar and
# we could eventually do things The Right Way and have them only differ in various
# variable settings.
#
# Most of the action is in other files.

provider "azurerm" {
  features {}
}

# Store state in WWT's Azure blob storage:

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.77"
    }
  }

  backend "azurerm" {
    resource_group_name  = "devops-support"
    storage_account_name = "wwtdevops"
    container_name       = "terraform-state"
    key                  = "dev.terraform.tfstate" # different than prod!
  }
}

# Base configuration properties of the active AzureRM setup:

data "azurerm_client_config" "current" {
}

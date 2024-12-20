# WWT Azure resource descriptions. Terraform docs:
#
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
#
# Most of the action is in other files.
#
# To update the provider:
#
# - Remove `.terraform.lock.hcl`
# - Update minimum version here
# - Run `terraform init -upgrade`
# - Run `terraform (plan|apply) -var-file=prod.tfvars -refresh-only`

provider "azurerm" {
  subscription_id = "581389a3-e46e-43a4-bef4-4d0c1c43e6a6"

  features {}
}

# Store state in WWT's Azure blob storage:

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.12"
    }
  }

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

# Support resource group; no obvious better place to put it right now

resource "azurerm_resource_group" "support" {
  name     = "devops-support"
  location = var.location

  lifecycle {
    prevent_destroy = true
  }
}

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
# - Run `terraform init`
# - Run `terraform (plan|apply) -var-file=prod.tfvars -refresh-only`

provider "azurerm" {
  features {}
}

# Store state in WWT's Azure blob storage:

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.41.0"
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

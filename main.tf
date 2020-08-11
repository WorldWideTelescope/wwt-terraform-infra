# Define the provider, version and feature set 
provider "azurerm" {
  version="~>2.0"
  features {}
}

# Create a resource group based on the prefix variable
# Note that here "main" is an alias for future use
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
}
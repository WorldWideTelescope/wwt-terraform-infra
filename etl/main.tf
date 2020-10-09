provider "azurerm" {
  version = "=2.8.0"
  features {}
}

resource "azurerm_resource_group" "rg" {
    name = "${var.prefix}-resources"
    location = var.location
}

resource "azurerm_virtual_network" "vnet1" {
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    name = "dev"
    address_space = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "subnet1" {
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet1.name
    name = "devsubnet"
    address_prefixes = ["10.20.0.0/24"]
}

resource "azurerm_public_ip" "pub_ip" {
    name = "vmpubip"
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
    allocation_method = "Dynamic"
}

resource "azurerm_network_interface" "vmnic" {
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
    name = "vmnic1"

    ip_configuration {
        name = "vmnic1-ipconf"
        subnet_id = azurerm_subnet.subnet1.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id = azurerm_public_ip.pub_ip.id
    }
}

resource "azurerm_windows_virtual_machine" "devvm" {
    name = "development-vm"
    location = var.location
    size = var.vm_sku
    admin_username = var.admin_username
    admin_password = var.admin_password
    resource_group_name = azurerm_resource_group.rg.name

    network_interface_ids = [azurerm_network_interface.vmnic.id]
    
    os_disk {
        caching = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer = "WindowsServer"
        sku = "2019-Datacenter"
        version = "latest"
    }
}
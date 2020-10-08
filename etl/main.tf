provider "azurerm" {
    version = "~>2.0"
    features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
}
output "resourcegroupname" { value = azurerm_resource_group.main.name }

resource "azurerm_virtual_network" "etlnetwork" {
    name                = "etlVnet"
    address_space       = ["10.0.0.0/16"]
    location            = var.location
    resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "etlsubnet" {
    name                 = "etlSubnet"
    resource_group_name  = azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.etlnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "etlpip" {
    name                         = "etlPublicIP"
    location                     = var.location
    resource_group_name          = azurerm_resource_group.main.name
    allocation_method            = "Dynamic"
}

resource "azurerm_network_security_group" "etlnsg" {
    name                = "etlNetworkSecurityGroup"
    location            = var.location
    resource_group_name = azurerm_resource_group.main.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_network_interface" "etlnic" {
    name                      = "etlNIC"
    location                  = var.location
    resource_group_name       = azurerm_resource_group.main.name

    ip_configuration {
        name                          = "etlNicConfiguration"
        subnet_id                     = azurerm_subnet.etlsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.etlpip.id
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "etl" {
    network_interface_id      = azurerm_network_interface.etlnic.id
    network_security_group_id = azurerm_network_security_group.etlnsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.main.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "etlvmstorage" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.main.name
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}

# Create (and display) an SSH key
resource "tls_private_key" "etl_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = tls_private_key.etl_ssh.private_key_pem }

# Create virtual machine
resource "azurerm_linux_virtual_machine" "etlvm" {
    name                  = "${var.prefix}etltaskvm"
    location              = var.location
    resource_group_name   = azurerm_resource_group.main.name
    network_interface_ids = [azurerm_network_interface.etlnic.id]
    size                  = var.vm_sku

    os_disk {
        name              = "linuxOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "etltasksvm"
    admin_username = var.admin_username
    disable_password_authentication = true

    admin_ssh_key {
        username       = var.admin_username
        public_key     = tls_private_key.etl_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.etlvmstorage.primary_blob_endpoint
    }
}
output "vm_name" { value = azurerm_linux_virtual_machine.etlvm.name }
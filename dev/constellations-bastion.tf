# A bastion host for the Constellations VPN so that we can see if things are
# actually working.
#
# To create the bastion, uncomment everything and generate an SSH key:
#
# `ssh-keygen -t rsa -b 4096 -C "wwt@cxbastion" -f bastion_rsa`
#
# Connect with:
#
# ```
# ssh -oIdentitiesOnly=yes -oPubkeyAcceptedAlgorithms=+ssh-rsa
#    -i bastion_rsa wwt@wwtdevcxb.westus.cloudapp.azure.com
# ```
#
# Then see, e.g. the header comment in `constellations-previewer.tf` for some
# hints about how to admin the previewer.

resource "azurerm_subnet" "cx_bastion" {
  name                 = "${var.prefix}-cxbastion"
  resource_group_name  = azurerm_resource_group.cx_backend.name
  virtual_network_name = azurerm_virtual_network.cx_backend.name
  address_prefixes     = ["10.0.220.0/24"]
}

resource "azurerm_public_ip" "cx_bastion" {
  name                = "${var.prefix}-cxbastion"
  resource_group_name = azurerm_resource_group.cx_backend.name
  location            = azurerm_resource_group.cx_backend.location
  allocation_method   = "Static"
  domain_name_label   = "${var.prefix}cxb"

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_network_interface" "cx_bastion" {
  name                = "${var.prefix}-cxbastion"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.cx_bastion.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.cx_bastion.id
  }
}

resource "azurerm_linux_virtual_machine" "cx_bastion" {
  name                = "${var.prefix}-cxbastion"
  computer_name       = "cxbastion"
  resource_group_name = azurerm_resource_group.cx_backend.name
  location            = azurerm_resource_group.cx_backend.location
  size                = "Standard_B1ls"
  admin_username      = "wwt"

  network_interface_ids = [
    azurerm_network_interface.cx_bastion.id
  ]

  admin_ssh_key {
    username   = "wwt"
    public_key = file("bastion_rsa.pub")
  }

  os_disk {
    name                 = "osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "83-gen2"
    version   = "latest"
  }
}

resource "azurerm_network_security_group" "cx_bastion" {
  name                = "${var.prefix}-cxbastion"
  location            = azurerm_resource_group.cx_backend.location
  resource_group_name = azurerm_resource_group.cx_backend.name

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

resource "azurerm_network_interface_security_group_association" "cx_bastion" {
  network_interface_id      = azurerm_network_interface.cx_bastion.id
  network_security_group_id = azurerm_network_security_group.cx_bastion.id
}

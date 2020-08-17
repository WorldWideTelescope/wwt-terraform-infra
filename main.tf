provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
}

resource "azurerm_storage_account" "datatier" {
  name                     = "${var.prefix}storage"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.1.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "main" {
  name                 = "main"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.1.2.0/24"]
}

resource "azurerm_public_ip_prefix" "main" {
  name                = "${var.prefix}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_windows_virtual_machine_scale_set" "main" {
  name                 = "${var.prefix}vmss"
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  sku                  = "Standard_F2s_v2"
  instances            = 2
  admin_username       = var.admin_user
  admin_password       = var.admin_password
  computer_name_prefix = var.prefix

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  network_interface {
    name    = "${var.prefix}nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.main.id

      public_ip_address {
        name                = "${var.prefix}pip"
        public_ip_prefix_id = azurerm_public_ip_prefix.main.id
      }
    }
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}


resource "azurerm_subnet_network_security_group_association" "main" {
  depends_on=[azurerm_network_security_group.main]
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_network_security_group" "main" {
  depends_on=[azurerm_resource_group.main]

  name = "${var.prefix}-vmss-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-rdp"
    description                = "allow-rdp"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    description                = "allow-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https"
    description                = "allow-https"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_machine_scale_set_extension" "vm_extension_install_iis" {
  name                       = "vm_extension_install_iis"
  virtual_machine_scale_set_id = azurerm_windows_virtual_machine_scale_set.main.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools"
    }
SETTINGS

  provisioner "local-exec" {
    interpreter = ["cmd", "/c"]
    command     = "az vmss wait --created -n ${azurerm_windows_virtual_machine_scale_set.main.name} -g ${azurerm_resource_group.main.name}"
  }

  provisioner "local-exec" {
    interpreter = ["cmd", "/c"]
    command     = "az vmss update-instances --instance-ids * -n ${azurerm_windows_virtual_machine_scale_set.main.name} -g ${azurerm_resource_group.main.name}"
  }
}

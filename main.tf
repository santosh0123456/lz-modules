provider "azurerm" {
  features {}
}

# ----------------------------
# Resource Group (reuse existing)
# ----------------------------
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}
data "http" "image_registry" {
  url = "https://raw.githubusercontent.com/santosh0123456/image-registry/main/images.json"
}
locals {
  images = jsondecode(data.http.image_registry.response_body)
}

# ----------------------------
# Virtual Network
# ----------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-main"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]
}

# ----------------------------
# Subnet
# ----------------------------
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-main"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
# ----------------------------
# Network Security Group
# ----------------------------
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-nginx"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ----------------------------
# Public IP
# ----------------------------
resource "azurerm_public_ip" "pip" {
  name                = "pip-nginx"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
}

# ----------------------------
# Network Interface
# ----------------------------
resource "azurerm_network_interface" "nic" {
  name                = "nic-nginx"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

# ----------------------------
# Attach NSG to NIC
# ----------------------------
resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ----------------------------
# Virtual Machine (using Packer image)
# ----------------------------
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-nginx"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B2s"

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

#  source_image_id = var.image_id
 source_image_id = "/subscriptions/71dc99cb-2548-4b6b-bf46-cd57e81fccaa/resourceGroups/maybankpoc/providers/Microsoft.Compute/galleries/packerimages/images/rhel9-nginx/versions/${local.images["rhel9-nginx"]}"

  os_disk {
    name                 = "osdisk-nginx"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  disable_password_authentication = true
}

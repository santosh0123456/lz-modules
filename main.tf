terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.7"   # must be 3.7+ for OIDC
    }
  }
#}
#terraform {
  backend "azurerm" {
    resource_group_name  = "crestsolution"
    storage_account_name = "crestsolution"
    container_name       = "tfestorage"
    key                  = "rhel9/rhel9.tfstate"
    
    use_oidc = true
    use_cli = false
  }
}
variable "github_token" {}
#variable "client_id" {}
#variable "tenant_id" {}
#variable "subscription_id" {}
#variable "oidc_token_file" {}
#variable "use_oidc" {}

provider "azurerm" {
  features {}
  use_oidc = true
  use_cli  = false         # ← REQUIRED

  #client_id       = var.client_id       # "19baf6b7-69ab-443e-ad52-77ee501d2ac0"
  #tenant_id       = var.tenant_id       # "c267b313-f395-45c7-82f9-325e4d530d90"
  #subscription_id = var.subscription_id # "71dc99cb-2548-4b6b-bf46-cd57e81fccaa"
  # oidc_token_file = var.oidc_token_file
#
}

# ----------------------------
# Resource Group (reuse existing)
# ----------------------------
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}
data "http" "image_registry" {
  #url = "https://raw.githubusercontent.com/santosh0123456/image-registry/main/images.json"
  url = "https://api.github.com/repos/santosh0123456/image-registry/contents/images.json"

  request_headers = {
    Authorization = "Bearer ${var.github_token}"
    Accept        = "application/vnd.github.v3.raw"
  }
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

resource "azurerm_public_ip" "nginx" {
  name                = "nginx-ip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "tomcat" {
  name                = "tomcat-ip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "mariadb" {
  name                = "mariadb-ip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# ----------------------------
# Network Interface
# ----------------------------
resource "azurerm_network_interface" "nginx" {
  name                = "nic-nginx"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nginx.id
  }
}

resource "azurerm_network_interface" "tomcat" {
  name                = "nic-tomcat"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tomcat.id
  }
}

resource "azurerm_network_interface" "mariadb" {
  name                = "nic-mariadb"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mariadb.id
  }
}
# ----------------------------
# Attach NSG to NIC
# ----------------------------
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  #network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ----------------------------
# Virtual Machine Nginx (using Packer image)
# ----------------------------
resource "azurerm_linux_virtual_machine" "vm-nginx" {
  name                = "vm-nginx"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B2s"

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nginx.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

#  source_image_id = var.image_id
 source_image_id = "/subscriptions/71dc99cb-2548-4b6b-bf46-cd57e81fccaa/resourceGroups/maybankpoc/providers/Microsoft.Compute/galleries/packerimages/images/rhel9-base/versions/${local.images["rhel9-base"]}"

  os_disk {
    name                 = "osdisk-nginx"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  disable_password_authentication = true
}
# ----------------------------
# Virtual Machine Tomcat (using Packer image)
# ----------------------------
resource "azurerm_linux_virtual_machine" "vm-tomcat" {
  name                = "vm-tomcat"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B2s"

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.tomcat.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

#  source_image_id = var.image_id
 source_image_id = "/subscriptions/71dc99cb-2548-4b6b-bf46-cd57e81fccaa/resourceGroups/maybankpoc/providers/Microsoft.Compute/galleries/packerimages/images/rhel9-base/versions/${local.images["rhel9-base"]}"

  os_disk {
    name                 = "osdisk-tomcat"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  disable_password_authentication = true
}
# ----------------------------
# Virtual Machine MariaDB (using Packer image)
# ----------------------------
resource "azurerm_linux_virtual_machine" "vm-mariadb" {
  name                = "vm-mariadb"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B2s"

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.mariadb.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

#  source_image_id = var.image_id
 source_image_id = "/subscriptions/71dc99cb-2548-4b6b-bf46-cd57e81fccaa/resourceGroups/maybankpoc/providers/Microsoft.Compute/galleries/packerimages/images/rhel9-base/versions/${local.images["rhel9-base"]}"

  os_disk {
    name                 = "osdisk-mariadb"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  disable_password_authentication = true
}

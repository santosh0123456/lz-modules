terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.7"
    }
  }
  backend "azurerm" {
    resource_group_name  = "crestsolution"
    storage_account_name = "crestsolution"
    container_name       = "tfestorage"
    key                  = "rhel9/rhel9.tfstate"

    use_oidc = true
    use_cli  = false
  }
}
# added
# ----------------------------
# Vault Provider
# ----------------------------
provider "vault" {
  address = "http://vault.tfeplatform.svc.cluster.local:8200"
  auth_login {
    path = "auth/kubernetes/login"
    parameters = {
      role = "tfe-role"
      jwt  = file("/var/run/secrets/kubernetes.io/serviceaccount/token")
    }
  }
}

# ----------------------------
# Fetch GitHub Token from Vault
# ----------------------------
data "vault_kv_secret_v2" "github" {
  mount = "secret"
  name  = "github"
}

locals {
  github_token = data.vault_kv_secret_v2.github.data.token
}

# ----------------------------
# Azure Provider
# ----------------------------
provider "azurerm" {
  features {}
  use_oidc = true
  use_cli  = false
}

# ----------------------------
# Resource Group (reuse existing)
# ----------------------------
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# ----------------------------
# Image Registry from GitHub
# ----------------------------
data "http" "image_registry" {
  url = "https://api.github.com/repos/santosh0123456/image-registry/contents/images.json"

  request_headers = {
    Authorization = "Bearer ${local.github_token}"
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

  security_rule {
    name                       = "allow-mysql"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ----------------------------
# Public IPs
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
# Network Interfaces
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
# NSG to Subnet Association
# ----------------------------
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ----------------------------
# Virtual Machine - Nginx
# ----------------------------
resource "azurerm_linux_virtual_machine" "vm-nginx" {
  name                = "vm-nginx"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B2s"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nginx.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

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
# Virtual Machine - Tomcat
# ----------------------------
resource "azurerm_linux_virtual_machine" "vm-tomcat" {
  name                = "vm-tomcat"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B2s"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.tomcat.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

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
# Virtual Machine - MariaDB
# ----------------------------
resource "azurerm_linux_virtual_machine" "vm-mariadb" {
  name                = "vm-mariadb"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B2s"
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.mariadb.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  source_image_id = "/subscriptions/71dc99cb-2548-4b6b-bf46-cd57e81fccaa/resourceGroups/maybankpoc/providers/Microsoft.Compute/galleries/packerimages/images/rhel9-base/versions/${local.images["rhel9-base"]}"

  os_disk {
    name                 = "osdisk-mariadb"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  disable_password_authentication = true
}

# ----------------------------
# Azure SQL Server
# ----------------------------
resource "azurerm_mssql_server" "sql" {
  name                         = "maybankpoc-sql-server"
  resource_group_name          = var.resource_group_name
  location                     = data.azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.admin_username
  administrator_login_password = var.sql_password

  public_network_access_enabled = true
}

# ----------------------------
# Azure SQL Database
# ----------------------------
resource "azurerm_mssql_database" "db" {
  name      = "maybankpoc-db"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "Basic"
}

# ----------------------------
# Ansible Configuration
# ----------------------------
resource "null_resource" "ansible_configure" {
  depends_on = [
    azurerm_linux_virtual_machine.vm-nginx,
    azurerm_linux_virtual_machine.vm-tomcat,
    azurerm_linux_virtual_machine.vm-mariadb
  ]

  provisioner "local-exec" {
    command = <<-EOT
      rm -rf /tmp/ansible
      git clone https://x-access-token:${local.github_token}@github.com/santosh0123456/ansible.git /tmp/ansible
      cd /tmp/ansible

      cat > inventory.ini <<EOF
[nginx]
${azurerm_public_ip.nginx.ip_address} ansible_user=${var.admin_username} ansible_ssh_private_key_file=/root/.ssh/id_rsa

[tomcat]
${azurerm_public_ip.tomcat.ip_address} ansible_user=${var.admin_username} ansible_ssh_private_key_file=/root/.ssh/id_rsa

[mariadb]
${azurerm_public_ip.mariadb.ip_address} ansible_user=${var.admin_username} ansible_ssh_private_key_file=/root/.ssh/id_rsa
EOF

      echo "Waiting for VMs to be SSH-ready..."
      sleep 30

      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini site.yml
    EOT
  }
}

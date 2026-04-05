terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}
variable "vault_addr" {}

provider "vault" {
  address = var.vault_addr
  auth_login {
    path = "auth/kubernetes/login"

    parameters = {
      role = "tfe-role"
      jwt  = file(var.kube_token_file)
    }
  }
}
data "vault_azure_access_credentials" "creds" {
  backend = "azure"
  role    = "tfe-role"
}
provider "azurerm" {
  features {}
  use_cli = false
 
  client_id       = data.vault_azure_access_credentials.creds.client_id
  client_secret   = chomp(data.vault_azure_access_credentials.creds.client_secret)
  tenant_id       = "c267b313-f395-45c7-82f9-325e4d530d90"
  subscription_id = "71dc99cb-2548-4b6b-bf46-cd57e81fccaa"
  #tenant_id       = data.vault_azure_access_credentials.creds.tenant_id
  #subscription_id = data.vault_azure_access_credentials.creds.subscription_id
}
resource "azurerm_resource_group" "network" {
  name = "rg_network_poc"
  location = "Southeast Asia"
}
output "vault_creds_debug" {
  value = {
    client_id       = data.vault_azure_access_credentials.creds.client_id
    tenant_id       = data.vault_azure_access_credentials.creds.tenant_id
    subscription_id = data.vault_azure_access_credentials.creds.subscription_id
  }
  sensitive = false
}
output "vault_secret_debug" {
  value     = data.vault_azure_access_credentials.creds.client_secret
  sensitive = true
}

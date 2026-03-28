terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}
provider "vault" {}

data "vault_azure_access_credentials" "creds" {
  backend = "azure"
  role    = "tfe-role"
}

provider "azurerm" {
  features {}
  use_cli = false

  client_id       = data.vault_azure_access_credentials.creds.client_id
  client_secret   = data.vault_azure_access_credentials.creds.client_secret
  tenant_id       = data.vault_azure_access_credentials.creds.tenant_id
  subscription_id = data.vault_azure_access_credentials.creds.subscription_id
}
resource "azurerm_resource_group" "network" {
  name = "rg_network_poc"
  location = "Southeast Asia"
}

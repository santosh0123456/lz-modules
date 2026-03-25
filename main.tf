terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}
provider "azurerm" {
  features {}
}
resource "azurerm_resource_group" "network" {
  name = "rg_network_poc"
  location = "Southeast Asia"
}

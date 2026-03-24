provider "azurerm" {
  features {}
}
resource "azurerm_resource_group" network {
  name = "rg_network_poc"
  location = "Southeast Asia"
}

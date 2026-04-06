terraform {
  required_providers {
    #vault   = { source = "hashicorp/vault",    version = "~> 3.0" }
    azurerm = { source = "hashicorp/azurerm",  version = "~> 3.100" }
    #time    = { source = "hashicorp/time",     version = "~> 0.9" }
  }
}
#variable "vault_addr" {}
variable "tfc_vault_backed_azure_dynamic_credentials" {
  type = object({
    default = object({
      client_id_file_path     = string
      client_secret_file_path = string
    })
    aliases = map(object({
      client_id_file_path     = string
      client_secret_file_path = string
    }))
  })
}
#variable "kube_token_file"{}

#provider "vault" {
#  address = var.vault_addr
#  auth_login {
#    path = "auth/kubernetes/login"
#
#    parameters = {
#      role = "tfe-role"
#      jwt  = file(var.kube_token_file)
#    }
#  }
#}
#data "vault_azure_access_credentials" "creds" {
#  backend = "azure"
#  role    = "tfe-role"
#  validate_creds              = false
#  num_sequential_successes    = 1
#  num_seconds_between_tests   = 1
#  max_cred_validation_seconds = 300
#}
#resource "time_sleep" "wait_for_aad_propagation" {
#  create_duration = "30s"
#
# triggers = {
#    # re-trigger the wait every time client_secret changes
 #   client_secret = data.vault_azure_access_credentials.creds.client_secret
  #}
#}

provider "azurerm" {
  features {}
  use_cli = false
  use_msi         = false

  client_id_file_path     = var.tfc_vault_backed_azure_dynamic_credentials.default.client_id_file_path
  client_secret_file_path = var.tfc_vault_backed_azure_dynamic_credentials.default.client_secret_file_path
  subscription_id = "71dc99cb-2548-4b6b-bf46-cd57e81fccaa"
  tenant_id       = "c267b313-f395-45c7-82f9-325e4d530d90"

 # client_id       = data.vault_azure_access_credentials.creds.client_id
 # client_secret   = chomp(data.vault_azure_access_credentials.creds.client_secret)
 # tenant_id       = "c267b313-f395-45c7-82f9-325e4d530d90"
 # subscription_id = "71dc99cb-2548-4b6b-bf46-cd57e81fccaa"
 # #tenant_id       = data.vault_azure_access_credentials.creds.tenant_id
 # #subscription_id = data.vault_azure_access_credentials.creds.subscription_id
}
resource "azurerm_resource_group" "network" {
  name = "rg_network_poc"
  location = "Southeast Asia"
}

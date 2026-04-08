terraform {
  required_providers {
    vault   = { source = "hashicorp/vault",    version = "~> 3.0" }
    azurerm = { source = "hashicorp/azurerm",  version = "~> 3.100" }
    time    = { source = "hashicorp/time",     version = "~> 0.9" }
  }
}

variable "vault_addr" {
  default = "http://vault.tfeplatform.svc.cluster.local:8200"
}

#variable "tfc_vault_backed_azure_dynamic_credentials" {
#  type = object({
#    default = object({
#      client_id_file_path     = string
#      client_secret_file_path = string
#    })
#  })
#}
variable "kube_token_file" {
  default  =  "/var/run/secrets/kubernetes.io/serviceaccount/token"
}

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
  validate_creds              = true
  num_sequential_successes    = 3
  num_seconds_between_tests   = 1
  max_cred_validation_seconds = 300
  tenant_id       = "c267b313-f395-45c7-82f9-325e4d530d90"
  subscription_id = "71dc99cb-2548-4b6b-bf46-cd57e81fccaa"
}
resource "time_sleep" "wait_for_azure_propagation" {
  depends_on = [data.vault_azure_access_credentials.creds]  
  create_duration = "30s"

  #triggers = {
  #  # re-trigger the wait every time client_secret changes
  #  client_secret = [data.vault_azure_access_credentials.creds.client_secret]
  #}
}

locals {
  # This local won't resolve until the 30s timer is up
  client_secret = time_sleep.wait_for_azure_propagation.id != "" ? data.vault_azure_access_credentials.creds.client_secret : ""
}

provider "azurerm" {
  features {}
  alias = "authenticated"
  use_cli = false
  use_msi         = false

 # client_id_file_path     = var.tfc_vault_backed_azure_dynamic_credentials.default.client_id_file_path
 # client_secret_file_path = var.tfc_vault_backed_azure_dynamic_credentials.default.client_secret_file_path
 # subscription_id = "71dc99cb-2548-4b6b-bf46-cd57e81fccaa"
 # tenant_id       = "c267b313-f395-45c7-82f9-325e4d530d90"

  skip_provider_registration = true
  storage_use_azuread = true
  client_certificate_password = time_sleep.wait_for_azure_propagation.id != "" ? null : null

  client_id       = data.vault_azure_access_credentials.creds.client_id
  client_secret   = data.vault_azure_access_credentials.creds.client_secret
  #client_id        = data.azurerm_subscription.current.client_id
  #client_secret   = data.azurerm_subscription.current.clinet_id != "" ? data.vault_azure_access_credentials.creds.data["client_secret"] : ""
  #client_secret   = local.client_secret
  #client_secret = nonsensitive(data.vault_azure_access_credentials.creds.client_secret)
  #client_id       = "20693731-319a-4bf1-a8c4-3bf9d33af319"
  #client_secret   = "ayk8Q~YiSyLOz9N~vq1sOzPia5-nJk2xbHqOGcka"
  tenant_id       = "c267b313-f395-45c7-82f9-325e4d530d90"
  #subscription_id = data.azurerm_subscription.current.subscription_id
  subscription_id = "71dc99cb-2548-4b6b-bf46-cd57e81fccaa"

 # #tenant_id       = data.vault_azure_access_credentials.creds.tenant_id
 # #subscription_id = data.vault_azure_access_credentials.creds.subscription_id
}
resource "azurerm_resource_group" "network" {
  provider = azurerm.authenticated
  name = "rg_network_poc"
  location = "Southeast Asia"
}

variable "resource_group_name" {
  default = "maybankpoc"
}

variable "admin_username" {
  default = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH Public Key"
}

variable "image_id" {
  description = "Packer Image ID"
}

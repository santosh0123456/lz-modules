variable "resource_group_name" {
  default = "maybankpoc"
}

variable "admin_username" {
  default = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH Public Key"
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDcKoP2IX5ii/EbyNNwCdvDrnhu5B4ckSwmVjUOUP98blH9sT7pizzQbWy8i31G4/Xu5LTsbBzxLtvkSQYReD4FSHEa3iqSTSQlcU48yIEOScZfhItZ/4dXeUCcMGfUWqBhPAGk33lwD7rTHsfrqUczeytpsUhA1VgVos+LGL2RM0FC4IwMDa3wpNrpiqSn8/hwqwFWpixAKjrnDloqfMaCjbcibiz/QSH+dzKChrxPzAseyDeQTgCsGmdmn/xsqEJiBGh2tDy1CCBKD2hQOmBZn4V/DiNemBbvNVJzzJT4LnxYzII9mE104c/aHqtNkczOnznf0oAepIL+FwSWu2LCB/xkRIKrSwXsMIUoqysWC5hntmTApMOdJSMXubOn/Jp19Ug4OeKxs9ziQCtyemj6ETdIVgSjZuL4d64kRtlRq4vHGQzkHT9KCXYysJIM2CbnuAdu3zaqGn91Y/iwbZLG+viTdjc+DChCX8wmCZH90FD5kFUndr6E9sRiTWG8aG0/tGGetp8qbJm0Vo5DTvNRbynIzeJ0ctfGFVDhrwYenXET2FK1YSQ0N2RF+VS5bIj+TpltPASJ/DRoshffJh2LqHcSJCypIgcFCRUG/NnWVj9iTYsLDGw2RClBKFATfB4q360HKr6pIPLJX1OvaVXdcPuGR4hXan8cxW9BnSCCOw== root@tfemgr.crestsolution.com"
}

#variable "image_id" {
#  description = "Packer Image ID"
#}

output "vm_ips" {
  value = {
    nginx  = azurerm_public_ip.nginx.ip_address
    tomcat = azurerm_public_ip.keycloak.ip_address
    db     = azurerm_public_ip.mariadb.ip_address
  }
}

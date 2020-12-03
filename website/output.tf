output "communities_default_url" {
  value = "https://${azurerm_app_service.wwt.default_site_hostname}"
}

output "data_default_url" {
  value = "https://${azurerm_app_service.data.default_site_hostname}"
}

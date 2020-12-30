output "communities_default_url" {
  value = "https://${azurerm_app_service.communities.default_site_hostname}"
}

output "data_default_url" {
  value = "https://${azurerm_app_service.data.default_site_hostname}"
}

output "data_stage_url" {
  value = "https://${azurerm_app_service_slot.data_stage.default_site_hostname}"
}

output "communities_default_url" {
  value = "https://${azurerm_app_service.communities.default_site_hostname}"
}

output "data_default_url" {
  value = "https://${azurerm_linux_web_app.data.default_hostname}"
}

output "data_stage_url" {
  value = "https://${azurerm_linux_web_app_slot.data_stage.default_hostname}"
}

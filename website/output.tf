output "communities_default_url" {
  value = "https://${azurerm_windows_web_app.communities.default_hostname}"
}

output "data_default_url" {
  value = "https://${azurerm_linux_web_app.data.default_hostname}"
}

output "data_stage_url" {
  value = "https://${azurerm_linux_web_app_slot.data_stage.default_hostname}"
}

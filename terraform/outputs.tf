# Outputs for Azure Traffic Manager Citrix Failover Example

output "traffic_manager_fqdn" {
  description = "The FQDN of the Traffic Manager profile"
  value       = azurerm_traffic_manager_profile.citrix_failover.fqdn
}

output "traffic_manager_profile_id" {
  description = "The ID of the Traffic Manager profile"
  value       = azurerm_traffic_manager_profile.citrix_failover.id
}

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.traffic_manager.name
}

output "primary_endpoint_status" {
  description = "Status of the primary endpoint"
  value       = azurerm_traffic_manager_external_endpoint.primary_isp.endpoint_status
}

output "backup_endpoint_status" {
  description = "Status of the backup endpoint"
  value       = azurerm_traffic_manager_external_endpoint.backup_isp.endpoint_status
}

output "automation_account_name" {
  description = "Name of the automation account"
  value       = azurerm_automation_account.failover_automation.name
}

output "action_group_id" {
  description = "ID of the action group for alerts"
  value       = azurerm_monitor_action_group.traffic_manager_alerts.id
}

output "dns_configuration_required" {
  description = "DNS configuration required for cutover"
  value = {
    type   = "CNAME"
    name   = "citrix.example.com"
    value  = azurerm_traffic_manager_profile.citrix_failover.fqdn
    ttl    = 300
  }
}

output "health_check_urls" {
  description = "URLs being monitored for health checks"
  value = {
    primary = "https://${var.primary_public_ip}${var.monitor_path}"
    backup  = "https://${var.backup_public_ip}${var.monitor_path}"
  }
}

output "manual_failover_commands" {
  description = "Commands for manual failover operations"
  value = {
    enable_backup = "az network traffic-manager endpoint update --resource-group ${azurerm_resource_group.traffic_manager.name} --name ${var.backup_endpoint_name} --type ExternalEndpoints --enabled true"
    disable_backup = "az network traffic-manager endpoint update --resource-group ${azurerm_resource_group.traffic_manager.name} --name ${var.backup_endpoint_name} --type ExternalEndpoints --enabled false"
  }
} 
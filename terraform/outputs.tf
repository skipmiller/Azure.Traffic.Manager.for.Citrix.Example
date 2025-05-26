# Outputs for Azure Traffic Manager Citrix Failover Example

output "traffic_manager_fqdn" {
  description = "The FQDN of the Traffic Manager profile for DNS configuration"
  value       = azurerm_traffic_manager_profile.citrix_failover.fqdn
}

output "traffic_manager_profile_id" {
  description = "The ID of the Traffic Manager profile"
  value       = azurerm_traffic_manager_profile.citrix_failover.id
}

output "resource_group_name" {
  description = "The name of the resource group containing all resources"
  value       = azurerm_resource_group.traffic_manager.name
}

output "resource_group_location" {
  value       = azurerm_resource_group.traffic_manager.location
  description = "The Azure region where resources are deployed"
}

output "traffic_manager_name" {
  description = "The name of the Traffic Manager profile"
  value       = azurerm_traffic_manager_profile.citrix_failover.name
}

output "primary_endpoint_name" {
  description = "The name of the primary ISP endpoint"
  value       = azurerm_traffic_manager_external_endpoint.primary_isp.name
}

output "backup_endpoint_name" {
  description = "The name of the backup ISP endpoint"
  value       = azurerm_traffic_manager_external_endpoint.backup_isp.name
}

output "automation_account_name" {
  description = "The name of the automation account"
  value       = azurerm_automation_account.failover_automation.name
}

output "automation_runbook_name" {
  description = "The name of the failover automation runbook"
  value       = azurerm_automation_runbook.enable_backup.name
}

output "webhook_uri" {
  sensitive   = true
  description = "The webhook URI for manual testing (keep secure)"
  value       = azurerm_automation_webhook.enable_backup_webhook.service_uri
}

output "early_warning_alert_name" {
  description = "The name of the early warning alert"
  value       = azurerm_monitor_metric_alert.primary_early_warning.name
}

output "critical_alert_name" {
  description = "The name of the critical alert that triggers failover"
  value       = azurerm_monitor_metric_alert.primary_failure_trigger_failover.name
}

output "action_group_name" {
  description = "The name of the action group for notifications"
  value       = azurerm_monitor_action_group.traffic_manager_alerts.name
}

output "dns_configuration_instructions" {
  value = <<-EOT
To complete the setup, update your DNS provider:

1. Login to your DNS management console
2. Find the record for your Citrix domain (e.g., citrix.example.com)
3. Change from A record to CNAME record
4. Point to: ${azurerm_traffic_manager_profile.citrix_failover.fqdn}
5. Set TTL to 300 seconds (5 minutes)

Example DNS Configuration:
Type: CNAME
Name: citrix
Value: ${azurerm_traffic_manager_profile.citrix_failover.fqdn}
TTL: 300
EOT
  description = "Instructions for DNS configuration"
}

output "testing_commands" {
  value = <<-EOT
Manual Testing Commands:

# Test DNS resolution
nslookup ${azurerm_traffic_manager_profile.citrix_failover.fqdn}

# Enable backup endpoint manually
az network traffic-manager endpoint update \
  --resource-group ${azurerm_resource_group.traffic_manager.name} \
  --profile-name ${azurerm_traffic_manager_profile.citrix_failover.name} \
  --name ${azurerm_traffic_manager_external_endpoint.backup_isp.name} \
  --type externalEndpoints \
  --endpoint-status Enabled

# Disable backup endpoint
az network traffic-manager endpoint update \
  --resource-group ${azurerm_resource_group.traffic_manager.name} \
  --profile-name ${azurerm_traffic_manager_profile.citrix_failover.name} \
  --name ${azurerm_traffic_manager_external_endpoint.backup_isp.name} \
  --type externalEndpoints \
  --endpoint-status Disabled

# Check endpoint status
az network traffic-manager endpoint list \
  --resource-group ${azurerm_resource_group.traffic_manager.name} \
  --profile-name ${azurerm_traffic_manager_profile.citrix_failover.name} \
  -o table
EOT
  description = "Commands for manual testing and management"
}

output "primary_endpoint_status" {
  description = "Status of the primary endpoint"
  value       = azurerm_traffic_manager_external_endpoint.primary_isp.endpoint_status
}

output "backup_endpoint_status" {
  description = "Status of the backup endpoint"
  value       = azurerm_traffic_manager_external_endpoint.backup_isp.endpoint_status
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
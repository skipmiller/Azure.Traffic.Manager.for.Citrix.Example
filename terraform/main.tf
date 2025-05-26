# Azure Traffic Manager for Enterprise Citrix Failover - Example Implementation
# This configuration demonstrates a cold standby failover solution

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

# Resource Group
resource "azurerm_resource_group" "traffic_manager" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "Production"
    Project     = "Citrix-Failover"
    Client      = "Enterprise-Corp"
    ManagedBy   = "Terraform"
    Purpose     = "Example-Implementation"
  }
}

# Action Group for Email Notifications
resource "azurerm_monitor_action_group" "traffic_manager_alerts" {
  name                = "traffic-manager-alerts"
  resource_group_name = azurerm_resource_group.traffic_manager.name
  short_name          = "tm-alerts"

  email_receiver {
    name          = "primary-admin"
    email_address = "admin@example.com"
  }

  email_receiver {
    name          = "business-contact"
    email_address = "business@example.com"
  }

  email_receiver {
    name          = "network-team"
    email_address = "network@example.com"
  }

  tags = {
    Environment = "Production"
    Project     = "Citrix-Failover"
    Client      = "Enterprise-Corp"
    ManagedBy   = "Terraform"
  }
}

# Traffic Manager Profile
resource "azurerm_traffic_manager_profile" "citrix_failover" {
  name                = var.traffic_manager_name
  resource_group_name = azurerm_resource_group.traffic_manager.name

  traffic_routing_method = "Priority"
  
  dns_config {
    relative_name = var.traffic_manager_name
    ttl           = 30
  }

  monitor_config {
    protocol                     = "HTTPS"
    port                        = 443
    path                        = "/logon/LogonPoint/index.html"
    interval_in_seconds         = 30
    timeout_in_seconds          = 10
    tolerated_number_of_failures = 3
  }

  tags = {
    Environment = "Production"
    Project     = "Citrix-Failover"
    Client      = "Enterprise-Corp"
    ManagedBy   = "Terraform"
  }
}

# Primary Endpoint (ISP A)
resource "azurerm_traffic_manager_external_endpoint" "primary_isp" {
  name       = "endpoint-primary-isp-prod"
  profile_id = azurerm_traffic_manager_profile.citrix_failover.id
  target     = var.primary_public_ip
  priority   = 1
  weight     = 1
  enabled    = true  # Always enabled
}

# Backup Endpoint (ISP B) - DISABLED BY DEFAULT for cold standby
resource "azurerm_traffic_manager_external_endpoint" "backup_isp" {
  name       = "endpoint-backup-isp-prod"
  profile_id = azurerm_traffic_manager_profile.citrix_failover.id
  target     = var.backup_public_ip
  priority   = 2
  weight     = 1
  enabled    = false  # DISABLED - backup is offline until needed
}

# Automation Account for Failover Management
resource "azurerm_automation_account" "failover_automation" {
  name                = "automation-citrix-failover"
  location            = azurerm_resource_group.traffic_manager.location
  resource_group_name = azurerm_resource_group.traffic_manager.name
  sku_name           = "Basic"

  # Enable system-assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
    Project     = "Citrix-Failover"
    Client      = "Enterprise-Corp"
    ManagedBy   = "Terraform"
  }
}

# Automation Runbook - Enable Backup Endpoint
resource "azurerm_automation_runbook" "enable_backup" {
  name                    = "Enable-BackupEndpoint"
  location                = azurerm_resource_group.traffic_manager.location
  resource_group_name     = azurerm_resource_group.traffic_manager.name
  automation_account_name = azurerm_automation_account.failover_automation.name
  log_verbose             = true
  log_progress            = true
  runbook_type           = "PowerShell"

  content = <<-EOT
param()

# Connect to Azure (using system-assigned managed identity)
Connect-AzAccount -Identity

# Configuration
$resourceGroupName = "${azurerm_resource_group.traffic_manager.name}"
$profileName = "${azurerm_traffic_manager_profile.citrix_failover.name}"
$backupEndpointName = "${azurerm_traffic_manager_external_endpoint.backup_isp.name}"

Write-Output "Starting failover process..."

# Enable the backup endpoint
try {
    Enable-AzTrafficManagerEndpoint `
        -Name $backupEndpointName `
        -ProfileName $profileName `
        -ResourceGroupName $resourceGroupName `
        -Type ExternalEndpoints
    
    Write-Output "Successfully enabled backup endpoint: $backupEndpointName"
    
    # Log notification details (email sending would require additional configuration)
    $subject = "FAILOVER ACTIVATED: Backup Connection Enabled"
    $body = @"
AUTOMATIC FAILOVER ACTIVATED

The primary ISP connection has failed. The backup ISP connection has been automatically enabled.

Time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Traffic Manager Profile: $profileName
Backup Endpoint: $backupEndpointName

Action Required:
1. Verify backup internet connection is powered on
2. Monitor citrix.example.com accessibility
3. Investigate primary connection failure

This is an automated message from Azure Traffic Manager.
"@
    
    Write-Output $body
    
} catch {
    Write-Error "Failed to enable backup endpoint: $_"
    throw
}
EOT

  tags = {
    Environment = "Production"
    Project     = "Citrix-Failover"
    Client      = "Enterprise-Corp"
    ManagedBy   = "Terraform"
  }
}

# Automation Runbook - Disable Backup Endpoint (for manual failback)
resource "azurerm_automation_runbook" "disable_backup" {
  name                    = "Disable-BackupEndpoint"
  location                = azurerm_resource_group.traffic_manager.location
  resource_group_name     = azurerm_resource_group.traffic_manager.name
  automation_account_name = azurerm_automation_account.failover_automation.name
  log_verbose             = true
  log_progress            = true
  runbook_type           = "PowerShell"

  content = <<-EOT
param()

# Connect to Azure (using system-assigned managed identity)
Connect-AzAccount -Identity

# Configuration
$resourceGroupName = "${azurerm_resource_group.traffic_manager.name}"
$profileName = "${azurerm_traffic_manager_profile.citrix_failover.name}"
$backupEndpointName = "${azurerm_traffic_manager_external_endpoint.backup_isp.name}"

Write-Output "Starting failback process..."

# Disable the backup endpoint
try {
    Disable-AzTrafficManagerEndpoint `
        -Name $backupEndpointName `
        -ProfileName $profileName `
        -ResourceGroupName $resourceGroupName `
        -Type ExternalEndpoints `
        -Force
    
    Write-Output "Successfully disabled backup endpoint: $backupEndpointName"
    
} catch {
    Write-Error "Failed to disable backup endpoint: $_"
    throw
}
EOT

  tags = {
    Environment = "Production"
    Project     = "Citrix-Failover"
    Client      = "Enterprise-Corp"
    ManagedBy   = "Terraform"
  }
}

# System-assigned Managed Identity for Automation Account
resource "azurerm_role_assignment" "automation_contributor" {
  scope                = azurerm_resource_group.traffic_manager.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.failover_automation.identity[0].principal_id

  depends_on = [azurerm_automation_account.failover_automation]
}

# Alert - Primary Failure triggers automation
resource "azurerm_monitor_metric_alert" "primary_failure_trigger_failover" {
  name                = "primary-isp-failure-auto-failover"
  resource_group_name = azurerm_resource_group.traffic_manager.name
  scopes              = [azurerm_traffic_manager_profile.citrix_failover.id]
  description         = "Primary endpoint failure - triggers automatic failover to backup"
  severity            = 0  # Critical
  frequency           = "PT1M"
  window_size         = "PT5M"
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Network/trafficManagerProfiles"
    metric_name      = "ProbeAgentCurrentEndpointStateByProfileResourceId"
    aggregation      = "Minimum"
    operator         = "LessThan"
    threshold        = 1

    dimension {
      name     = "EndpointName"
      operator = "Include"
      values   = ["endpoint-primary-isp-prod"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.traffic_manager_alerts.id
  }

  tags = {
    Environment = "Production"
    Project     = "Citrix-Failover"
    Client      = "Enterprise-Corp"
    ManagedBy   = "Terraform"
  }
}

# Logic App to trigger automation runbook on alert
resource "azurerm_logic_app_workflow" "failover_trigger" {
  name                = "logic-app-failover-trigger"
  location            = azurerm_resource_group.traffic_manager.location
  resource_group_name = azurerm_resource_group.traffic_manager.name

  tags = {
    Environment = "Production"
    Project     = "Citrix-Failover"
    Client      = "Enterprise-Corp"
    ManagedBy   = "Terraform"
  }
} 
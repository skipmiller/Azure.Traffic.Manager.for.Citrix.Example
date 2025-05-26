# Azure Traffic Manager for Enterprise Citrix Failover - Example Implementation
# This configuration demonstrates a cold standby failover solution with webhook-based automation

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
    tolerated_number_of_failures = 9
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

# Role Assignment for Automation Account
resource "azurerm_role_assignment" "automation_contributor" {
  scope                = azurerm_resource_group.traffic_manager.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.failover_automation.identity[0].principal_id
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

# Update runbook content and publish
resource "null_resource" "update_runbook_content" {
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for runbook to be created
      sleep 30
      
      # Create the PowerShell script
      cat > enable-backup.ps1 << 'EOF'
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
    
} catch {
    Write-Error "Failed to enable backup endpoint: $_"
    throw
}
EOF

      # Update the runbook content
      az automation runbook replace-content \
        --automation-account-name ${azurerm_automation_account.failover_automation.name} \
        --resource-group ${azurerm_resource_group.traffic_manager.name} \
        --name ${azurerm_automation_runbook.enable_backup.name} \
        --content @enable-backup.ps1

      # Publish the runbook
      az automation runbook publish \
        --automation-account-name ${azurerm_automation_account.failover_automation.name} \
        --resource-group ${azurerm_resource_group.traffic_manager.name} \
        --name ${azurerm_automation_runbook.enable_backup.name}

      # Clean up
      rm enable-backup.ps1
    EOT
  }

  depends_on = [azurerm_automation_runbook.enable_backup]

  triggers = {
    runbook_id = azurerm_automation_runbook.enable_backup.id
  }
}

# Automation Webhook for Direct Alert Integration
resource "azurerm_automation_webhook" "enable_backup_webhook" {
  name                    = "webhook-enable-backup"
  resource_group_name     = azurerm_resource_group.traffic_manager.name
  automation_account_name = azurerm_automation_account.failover_automation.name
  expiry_time            = timeadd(timestamp(), "8760h") # 1 year from now
  enabled                = true
  runbook_name           = azurerm_automation_runbook.enable_backup.name

  depends_on = [null_resource.update_runbook_content]
}

# Action Group with Email and Webhook Integration
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

  # Webhook receiver for automation - Direct alert-to-automation connection
  automation_runbook_receiver {
    name                    = "enable-backup-automation"
    automation_account_id   = azurerm_automation_account.failover_automation.id
    runbook_name           = azurerm_automation_runbook.enable_backup.name
    webhook_resource_id    = azurerm_automation_webhook.enable_backup_webhook.id
    is_global_runbook      = false
    service_uri            = azurerm_automation_webhook.enable_backup_webhook.service_uri
    use_common_alert_schema = true
  }

  tags = {
    Environment = "Production"
    Project     = "Citrix-Failover"
    Client      = "Enterprise-Corp"
    ManagedBy   = "Terraform"
  }
}

# STAGE 1: Early Warning Alert (1 minute) - EMAIL ONLY
resource "azurerm_monitor_metric_alert" "primary_early_warning" {
  name                = "primary-isp-early-warning"
  resource_group_name = azurerm_resource_group.traffic_manager.name
  scopes              = [azurerm_traffic_manager_profile.citrix_failover.id]
  description         = "Early warning: Primary ISP endpoint experiencing issues"
  severity            = 2  # Warning level
  frequency           = "PT1M"
  window_size         = "PT1M"  # Ultra-fast: 1-minute detection
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Network/trafficManagerProfiles"
    metric_name      = "ProbeAgentCurrentEndpointStateByProfileResourceId"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 0.8

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

# STAGE 2: Critical Alert with Automation (5 minutes)
resource "azurerm_monitor_metric_alert" "primary_failure_trigger_failover" {
  name                = "primary-isp-failure-auto-failover"
  resource_group_name = azurerm_resource_group.traffic_manager.name
  scopes              = [azurerm_traffic_manager_profile.citrix_failover.id]
  description         = "CRITICAL: Primary endpoint failure - automatic failover will trigger"
  severity            = 0  # Critical level
  frequency           = "PT1M"
  window_size         = "PT5M"  # Ultra-fast: 5-minute sustained failure
  enabled             = true

  criteria {
    metric_namespace = "Microsoft.Network/trafficManagerProfiles"
    metric_name      = "ProbeAgentCurrentEndpointStateByProfileResourceId"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 0.3

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
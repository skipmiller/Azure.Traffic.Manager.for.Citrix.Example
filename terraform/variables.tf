# Azure Traffic Manager Variables for Enterprise Citrix Failover Example

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-traffic-mgr-citrix-example"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West US"
}

variable "traffic_manager_name" {
  description = "Name of the Traffic Manager profile"
  type        = string
  default     = "traffic-mgr-citrix-prod-example"
}

variable "primary_public_ip" {
  description = "Primary ISP connection public IP (example)"
  type        = string
  default     = "203.0.113.10"  # RFC 5737 test range
}

variable "backup_public_ip" {
  description = "Backup ISP connection public IP (example)"
  type        = string
  default     = "198.51.100.35"  # RFC 5737 test range
}

variable "primary_endpoint_name" {
  description = "Name for the primary endpoint"
  type        = string
  default     = "endpoint-primary-isp-prod"
}

variable "backup_endpoint_name" {
  description = "Name for the backup endpoint"
  type        = string
  default     = "endpoint-backup-isp-prod"
}

variable "dns_ttl" {
  description = "DNS TTL for Traffic Manager"
  type        = number
  default     = 30
}

variable "monitor_protocol" {
  description = "Protocol for health monitoring"
  type        = string
  default     = "HTTPS"
}

variable "monitor_port" {
  description = "Port for health monitoring"
  type        = number
  default     = 443
}

variable "monitor_path" {
  description = "Path for health monitoring"
  type        = string
  default     = "/logon/LogonPoint/index.html"
}

variable "monitor_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 10
}

variable "monitor_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "monitor_failures_tolerated" {
  description = "Number of failures tolerated before marking endpoint as degraded"
  type        = number
  default     = 2
}

variable "backup_endpoint_enabled" {
  description = "Whether the backup endpoint should be enabled (for cold standby, default is false)"
  type        = bool
  default     = false
}

variable "enable_automation" {
  description = "Whether to create automation resources for automatic failover"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Production"
    Project     = "Citrix-Failover"
    Client      = "Enterprise-Corp"
    ManagedBy   = "Terraform"
    Purpose     = "Example-Implementation"
  }
}

# Network Configuration Variables (for documentation)
variable "citrix_internal_ip" {
  description = "Citrix server internal IP (example)"
  type        = string
  default     = "10.0.1.15"
}

variable "core_switch_ip" {
  description = "Core switch IP (example)"
  type        = string
  default     = "10.0.1.1"
}

variable "primary_firewall_internal_ip" {
  description = "Primary firewall internal IP (example)"
  type        = string
  default     = "10.0.1.254"
}

variable "backup_firewall_internal_ip" {
  description = "Backup firewall internal IP (example)"
  type        = string
  default     = "10.0.2.254"
} 
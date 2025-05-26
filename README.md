# Azure Traffic Manager for Citrix Cold Standby Failover - Example Implementation

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-blue.svg)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Azure-Traffic%20Manager-blue.svg)](https://azure.microsoft.com/en-us/services/traffic-manager/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

This repository demonstrates a production-ready Azure Traffic Manager implementation for Citrix Virtual Apps failover using a **cold standby** configuration with **webhook-based automation**. The solution provides ultra-fast automatic failover between dual ISP connections while optimizing costs by keeping the backup connection offline during normal operations.

## 🏗️ Architecture

### Cold Standby Design with Webhook Automation
- **Primary ISP:** Always online and monitored (203.0.113.10)
- **Backup ISP:** Offline until needed, automatically enabled during failover (198.51.100.35)
- **DNS Routing:** External DNS points to Azure Traffic Manager FQDN
- **Webhook Integration:** Direct alert-to-automation connection for reliability
- **Two-Stage Alerting:** Early warning (1 min) and critical alert (5 min)

### Key Features
- ⚡ **Ultra-fast failover:** 5-minute automatic failover (vs. 15-30 minutes manual)
- 🔗 **Webhook-based automation:** More reliable than Logic App workflows
- 💰 **Cost optimization:** Backup ISP only active during outages
- 🤖 **Fully automated** failover with email notifications
- 📊 **Infrastructure as Code** using Terraform
- 🔒 **Secure** using Azure Managed Identity
- ⚠️ **Manual intervention window:** 4 minutes to investigate before auto-failover

## 🚀 Quick Start

### Prerequisites
- Azure CLI installed and authenticated
- Terraform >= 1.0
- Contributor access to Azure subscription

### Deployment
```bash
# Clone the repository
git clone <repository-url>
cd Azure.Traffic.Manager.for.Citrix.Example

# Navigate to terraform directory
cd terraform/

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your actual values

# Initialize and deploy
terraform init
terraform plan
terraform apply
```

### DNS Configuration
After deployment, update your DNS provider:
```bash
# Get the Traffic Manager FQDN
terraform output traffic_manager_fqdn

# Update your DNS:
# Type: CNAME
# Name: citrix (or your subdomain)
# Value: <traffic-manager-fqdn>
# TTL: 300 seconds
```

## 🔧 Configuration

### Required Variables
Update `terraform.tfvars` with your specific values:

```hcl
# Resource configuration
resource_group_name  = "rg-traffic-manager-citrix-prod"
location            = "West US 2"
traffic_manager_name = "tm-citrix-failover-prod"

# ISP public IP addresses
primary_public_ip = "203.0.113.10"   # Your primary ISP public IP
backup_public_ip  = "198.51.100.35"  # Your backup ISP public IP
```

### Email Notifications
The system sends alerts to three email addresses:
- **admin@example.com** - Technical administrator
- **business@example.com** - Business stakeholder  
- **network@example.com** - Network team

Update these in the `main.tf` file or use variables.

## 📊 How It Works

### Normal Operations
1. Traffic Manager routes all DNS queries to primary ISP (203.0.113.10)
2. Health checks verify primary connection every 30 seconds
3. Backup ISP endpoint remains disabled (offline) to minimize costs
4. Users access `citrix.example.com` → primary ISP connection

### Failure Detection & Response

#### Stage 1: Early Warning (1-2 minutes)
- **1 minute:** Primary ISP issues detected over 1-minute window
- **1-2 minutes:** 📧 **WARNING EMAIL** sent to all stakeholders
- **Action:** Team can investigate and resolve manually

#### Stage 2: Critical Alert & Automation (5-6 minutes)
- **5 minutes:** Sustained failure confirmed over 5-minute window
- **5-6 minutes:** 📧 **CRITICAL EMAIL** sent + 🤖 **Webhook triggers automation**
- **6+ minutes:** Backup ISP automatically enabled, users routed to backup

### Manual Intervention Window
- **4-minute window** between early warning and critical alert
- Time to investigate and resolve minor issues
- Prevents unnecessary failovers for brief outages
- Automatic failover only for sustained failures (5+ minutes)

## 🔄 Automation Architecture

### Webhook-Based Approach (Recommended)
This implementation uses the **standard Azure automation pattern**:
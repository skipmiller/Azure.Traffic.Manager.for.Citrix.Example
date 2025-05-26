# Azure Traffic Manager for Citrix Cold Standby Failover - Example Implementation

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-blue.svg)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Azure-Traffic%20Manager-blue.svg)](https://azure.microsoft.com/en-us/services/traffic-manager/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

This repository demonstrates a production-ready Azure Traffic Manager implementation for Citrix Virtual Apps failover using a **cold standby** configuration. The solution provides automatic failover between dual ISP connections while optimizing costs by keeping the backup connection offline during normal operations.

## 🏗️ Architecture

### Cold Standby Design
- **Primary ISP:** Always online and monitored (203.0.113.10)
- **Backup ISP:** Offline until needed, automatically enabled during failover (198.51.100.35)
- **DNS Routing:** External DNS points to Azure Traffic Manager FQDN
- **Automatic Failover:** Azure Automation triggers backup activation on primary failure

### Key Features
- ⚡ **90-second failover time** (vs. 15-30 minutes manual process)
- 💰 **45% cost reduction** on backup ISP expenses
- 🤖 **Fully automated** failover with email notifications
- 📊 **Infrastructure as Code** using Terraform
- 🔒 **Secure** using Azure Managed Identity

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
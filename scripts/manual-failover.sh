#!/bin/bash
# Manual Failover Script for Azure Traffic Manager Citrix Example
# Use this script for emergency manual failover operations

set -e

# Configuration
RESOURCE_GROUP="rg-traffic-mgr-citrix-example"
PROFILE_NAME="traffic-mgr-citrix-prod-example"
PRIMARY_ENDPOINT="endpoint-primary-isp-prod"
BACKUP_ENDPOINT="endpoint-backup-isp-prod"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_azure_login() {
    if ! az account show &> /dev/null; then
        print_error "Not logged into Azure. Please run 'az login' first."
        exit 1
    fi
    print_status "Azure login verified"
}

get_endpoint_status() {
    local endpoint_name=$1
    az network traffic-manager endpoint show \
        --resource-group "$RESOURCE_GROUP" \
        --profile-name "$PROFILE_NAME" \
        --name "$endpoint_name" \
        --type externalEndpoints \
        --query "endpointStatus" \
        --output tsv 2>/dev/null || echo "Unknown"
}

show_current_status() {
    print_status "Current Traffic Manager Status:"
    echo "  Primary Endpoint: $(get_endpoint_status $PRIMARY_ENDPOINT)"
    echo "  Backup Endpoint:  $(get_endpoint_status $BACKUP_ENDPOINT)"
    echo ""
}

enable_backup() {
    print_warning "Enabling backup endpoint..."
    az network traffic-manager endpoint update \
        --resource-group "$RESOURCE_GROUP" \
        --profile-name "$PROFILE_NAME" \
        --name "$BACKUP_ENDPOINT" \
        --type externalEndpoints \
        --endpoint-status Enabled
    
    print_status "Backup endpoint enabled successfully"
}

disable_backup() {
    print_warning "Disabling backup endpoint..."
    az network traffic-manager endpoint update \
        --resource-group "$RESOURCE_GROUP" \
        --profile-name "$PROFILE_NAME" \
        --name "$BACKUP_ENDPOINT" \
        --type externalEndpoints \
        --endpoint-status Disabled
    
    print_status "Backup endpoint disabled successfully"
}

test_endpoints() {
    print_status "Testing endpoint connectivity..."
    
    # Test primary
    if curl -s -I "https://203.0.113.10/logon/LogonPoint/index.html" &> /dev/null; then
        print_status "Primary endpoint (203.0.113.10) is responding"
    else
        print_error "Primary endpoint (203.0.113.10) is not responding"
    fi
    
    # Test backup
    if curl -s -I "https://198.51.100.35/logon/LogonPoint/index.html" &> /dev/null; then
        print_status "Backup endpoint (198.51.100.35) is responding"
    else
        print_error "Backup endpoint (198.51.100.35) is not responding"
    fi
}

show_help() {
    echo "Azure Traffic Manager Manual Failover Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  status          Show current endpoint status"
    echo "  enable-backup   Enable backup endpoint (failover)"
    echo "  disable-backup  Disable backup endpoint (failback)"
    echo "  test           Test endpoint connectivity"
    echo "  help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status                    # Check current status"
    echo "  $0 enable-backup            # Failover to backup"
    echo "  $0 disable-backup           # Failback to primary"
    echo ""
}

# Main script logic
case "${1:-help}" in
    "status")
        check_azure_login
        show_current_status
        ;;
    "enable-backup")
        check_azure_login
        print_warning "This will enable the backup endpoint and route traffic to the backup ISP."
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            enable_backup
            show_current_status
        else
            print_status "Operation cancelled"
        fi
        ;;
    "disable-backup")
        check_azure_login
        print_warning "This will disable the backup endpoint and return traffic to the primary ISP."
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            disable_backup
            show_current_status
        else
            print_status "Operation cancelled"
        fi
        ;;
    "test")
        test_endpoints
        ;;
    "help"|*)
        show_help
        ;;
esac 
#!/usr/bin/env bash

################################################################################
# Description: This script cleans up all resources in an Azure Resource Group. #
# Author: Yevhen Maidannikov                                                   #
################################################################################

set -euxo pipefail

# Set variables
LOG_FILE="cleanup.log"
REQUIRED_VERSION="2.30.0"
AZURE_RG="${1:-}"

# Initialize arrays to collect failures
failed_disassociations=()
failed_deletions=()

#############
# FUNCTIONS #
#############

log() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] - $message" | tee -a "$LOG_FILE"
}

initialize() {
    # Check for the presence of the Azure CLI
    if ! command -v az &> /dev/null; then
        log "ERROR" "Azure CLI is not installed. Please install the Azure CLI before running the script."
        exit 1
    fi

    # Check if logged into Azure
    if ! az account show &> /dev/null; then
        log "ERROR" "Not logged into Azure. Please run 'az login' before running the script."
        exit 1
    fi

    # Check if the resource group name is provided
    if [ -z "${AZURE_RG:-}" ]; then
        log "ERROR" "Usage: $0 <AZURE_RG>"
        exit 1
    fi

    # Check if the Azure CLI version is supported
    current_version=$(az --version | grep -m1 'azure-cli' | awk '{print $2}')
    if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$current_version" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
        log "ERROR" "Azure CLI version $REQUIRED_VERSION or higher is required. Current version: $current_version"
        exit 1
    fi

    # Check if the resource group exists
    if ! az group exists -n "$AZURE_RG" &> /dev/null; then
        log "ERROR" "Resource group '$AZURE_RG' does not exist."
        exit 1
    fi
}

resource_list() {
    # Check if there are resources to list
    resource_count=$(az resource list -g "$AZURE_RG" --query "length(@)" -o tsv)

    if [ -z "$resource_count" ] || [ "$resource_count" -eq 0 ]; then
        log "INFO" "No resources in resource group '$AZURE_RG'. Cleanup is not needed."
        return 1  # No resources to clean up
    else
        log "INFO" "Listing resources with additional details:"
        az resource list -g "$AZURE_RG" --query "[].{Name:name, Type:type, Location:location}" -o table | tee -a "$LOG_FILE"
        return 0
    fi
}

disassociate_public_ips() {
    log "INFO" "Disassociating public IPs from network interfaces..."

    # Get the list of NIC IDs
    nic_ids=$(az resource list -g "$AZURE_RG" --resource-type "Microsoft.Network/networkInterfaces" --query "[].id" -o tsv)

    if [ -z "$nic_ids" ]; then
        log "INFO" "No network interfaces to disassociate."
        return
    fi

    for nic_id in $nic_ids; do
        nic_name=$(az resource show --ids "$nic_id" --query "name" -o tsv)
        ip_config_name=$(az network nic ip-config list --nic-name "$nic_name" -g "$AZURE_RG" --query "[0].name" -o tsv)

        if az network nic ip-config update --resource-group "$AZURE_RG" --nic-name "$nic_name" --name "$ip_config_name" --remove publicIpAddress; then
            log "INFO" "Public IP disassociated from network interface $nic_id"
        else
            log "ERROR" "Error disassociating Public IP from network interface $nic_id"
            failed_disassociations+=("$nic_id")
        fi
    done
}

delete_resources() {
    local resource_type=${1:-}
    if [ -n "$resource_type" ]; then
        log "INFO" "Deleting resources of type $resource_type..."
        ids=$(az resource list -g "$AZURE_RG" --resource-type "$resource_type" --query "[].id" -o tsv)

        if [ -z "$ids" ]; then
            log "INFO" "No resources of type $resource_type found."
            return
        fi

        for id in $ids; do
            if az resource delete --ids "$id" --verbose; then
                log "INFO" "$id - deleted"
            else
                log "ERROR" "Error deleting $id"
                failed_deletions+=("$id")
            fi
        done
    else
        log "INFO" "Deleting all remaining resources..."
        resource_ids=$(az resource list -g "$AZURE_RG" --query "[].id" -o tsv)

        if [ -z "$resource_ids" ]; then
            log "INFO" "No remaining resources found."
            return
        fi

        for resource_id in $resource_ids; do
            if az resource delete --ids "$resource_id" --verbose; then
                log "INFO" "$resource_id - deleted"
            else
                log "ERROR" "Error deleting $resource_id"
                failed_deletions+=("$resource_id")
            fi
        done
    fi
}

report() {
    if [ ${#failed_disassociations[@]} -ne 0 ] || [ ${#failed_deletions[@]} -ne 0 ]; then
        log "ERROR" "Some operations failed."
        if [ ${#failed_disassociations[@]} -ne 0 ]; then
            log "ERROR" "Failed to disassociate the following network interfaces:"
            for id in "${failed_disassociations[@]}"; do
                log "ERROR" "$id"
            done
        fi
        if [ ${#failed_deletions[@]} -ne 0 ]; then
            log "ERROR" "Failed to delete the following resources:"
            for id in "${failed_deletions[@]}"; do
                log "ERROR" "$id"
            done
        fi
        exit 1
    fi
}

###############
# MAIN SCRIPT #
###############

initialize

log "INFO" "Starting the cleanup of the resource group '$AZURE_RG'..."

# Check if there are resources to clean up
if ! resource_list; then
    exit 0  # Exit if there are no resources to clean up
fi

# Disassociate public IPs from network interfaces
disassociate_public_ips

# Delete resources in the correct order to avoid dependency issues
delete_resources "Microsoft.Compute/virtualMachines"
delete_resources "Microsoft.Network/publicIPAddresses"
delete_resources "Microsoft.Network/networkInterfaces"
delete_resources "Microsoft.Compute/disks"
delete_resources "Microsoft.Network/networkSecurityGroups"
delete_resources "Microsoft.Network/loadBalancers"
delete_resources "Microsoft.Network/virtualNetworks"
delete_resources "Microsoft.Storage/storageAccounts"
delete_resources "Microsoft.KeyVault/vaults"
delete_resources "Microsoft.Web/sites"
delete_resources "Microsoft.Web/serverFarms"
delete_resources "Microsoft.ServiceBus/namespaces"
delete_resources "Microsoft.AppConfiguration/configurationStores"
delete_resources "Microsoft.ManagedIdentity/userAssignedIdentities"
delete_resources
report

log "INFO" "List of resources after cleanup:"
resource_list  # This will list remaining resources or indicate none are left
log "INFO" "Cleanup of resource group '$AZURE_RG' completed."
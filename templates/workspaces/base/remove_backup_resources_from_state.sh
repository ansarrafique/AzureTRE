#!/bin/bash

set -o errexit
set -o pipefail

# Uncomment this line to see each command for debugging
# set -o xtrace

function usage() {
    cat <<USAGE
Usage: $0 --backup_enabled true|false --use_azuread_auth true|false --resource_group_name rg_name --storage_account_name sa_name --container_name container --key backend_key

Options:
    --backup_enabled         Whether backup is enabled (true|false)
    --use_azuread_auth       Whether to use Azure AD auth (true|false)
    --resource_group_name    Backend resource group name
    --storage_account_name   Backend storage account name
    --container_name         Terraform state container name
    --key                    Backend key for terraform state
USAGE
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

backup_enabled=""
use_azuread_auth=""
backend_rg_name=""
backend_storage_account_name=""
terraform_state_container_name=""
backend_key=""

# Parse Porter flags.
while [ "$#" -gt 0 ]; do
    case "$1" in
    --backup_enabled)
        backup_enabled="$2"
        shift 2
        ;;
    --use_azuread_auth)
        use_azuread_auth="$2"
        shift 2
        ;;
    --resource_group_name)
        backend_rg_name="$2"
        shift 2
        ;;
    --storage_account_name)
        backend_storage_account_name="$2"
        shift 2
        ;;
    --container_name)
        terraform_state_container_name="$2"
        shift 2
        ;;
    --key)
        backend_key="$2"
        shift 2
        ;;
    *)
        echo "Unexpected argument: '$1'"
        usage
        ;;
    esac
done

set -o nounset

cd terraform/
terraform version

terraform init -input=false -backend=true -reconfigure \
    -backend-config="resource_group_name=${backend_rg_name}" \
    -backend-config="storage_account_name=${backend_storage_account_name}" \
    -backend-config="container_name=${terraform_state_container_name}" \
    -backend-config="key=${backend_key}" \
    -backend-config="use_azuread_auth=${use_azuread_auth}"

# Read the current state once.
state_list="$(terraform state list || true)"

# Exact Terraform state addresses for resources we want to unmanage.
# terraform state rm removes them from state only; it does NOT delete the Azure resources.
explicit_resources=(
    "azurerm_resource_group.ws"
    "azurerm_storage_account.stg"
    "azurerm_storage_container.stgcontainer"
    "azurerm_storage_account_network_rules.stgrules"
    "azapi_resource.shared_storage"
    "azurerm_key_vault.kv"
    "azurerm_private_endpoint.stgfilepe"
    "azurerm_private_endpoint.stgblobpe"
    "azurerm_private_endpoint.stgdfspe"
)

echo "Removing core workspace resources from Terraform state..."

for resource in "${explicit_resources[@]}"; do
    if echo "$state_list" | grep -Fxq "$resource"; then
        echo "Removing from state: $resource"
        terraform state rm "$resource" || true
    fi
done

# If backup is enabled, remove the whole backup module from state as well.
# This leaves the backup-related Azure resources orphaned intentionally,
# so Porter/Terraform can continue uninstalling the rest of the workspace.
if [[ "${backup_enabled}" == "true" ]]; then
    echo "Removing backup module resources from Terraform state..."

    while IFS= read -r resource; do
        if [ -n "$resource" ]; then
            echo "Removing from state: $resource"
            terraform state rm "$resource" || true
        fi
    done < <(echo "$state_list" | grep -E '^module\.backup' || true)
fi

cd ..
echo "Backup-related state cleanup complete."
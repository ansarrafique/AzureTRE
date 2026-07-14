#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

# Uncomment this line to see each command for debugging
# set -o xtrace

function usage() {
    cat <<USAGE
Usage:
  $0 --backup_enabled true|false --use_azuread_auth true|false \
     --resource_group_name rg_name --storage_account_name sa_name \
     --container_name container --key backend_key \
     [--workspace_resource_group_name workspace_rg_name]

Options:
    --backup_enabled                  Whether backup is enabled (true|false)
    --use_azuread_auth                Whether to use Azure AD auth (true|false)
    --resource_group_name             Backend resource group name
    --storage_account_name            Backend storage account name
    --container_name                  Terraform state container name
    --key                             Terraform state key
    --workspace_resource_group_name   Workspace resource group name.
                                      If omitted, the script will try to derive it as rg-${backend_key}.
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
workspace_rg_name=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --backup_enabled)
            backup_enabled="${2:-}"
            shift 2
            ;;
        --use_azuread_auth)
            use_azuread_auth="${2:-}"
            shift 2
            ;;
        --resource_group_name)
            backend_rg_name="${2:-}"
            shift 2
            ;;
        --storage_account_name)
            backend_storage_account_name="${2:-}"
            shift 2
            ;;
        --container_name)
            terraform_state_container_name="${2:-}"
            shift 2
            ;;
        --key)
            backend_key="${2:-}"
            shift 2
            ;;
        --workspace_resource_group_name)
            workspace_rg_name="${2:-}"
            shift 2
            ;;
        *)
            echo "Unexpected argument: '$1'"
            usage
            ;;
    esac
done

if [ -z "${backup_enabled}" ] || \
   [ -z "${use_azuread_auth}" ] || \
   [ -z "${backend_rg_name}" ] || \
   [ -z "${backend_storage_account_name}" ] || \
   [ -z "${terraform_state_container_name}" ] || \
   [ -z "${backend_key}" ]; then
    echo "Missing required arguments."
    usage
fi

cd terraform/
terraform version

echo "Target RG: ${backend_rg_name}"
echo "Target SA: ${backend_storage_account_name}"
echo "Container: ${terraform_state_container_name}"
echo "Workspace Key: ${backend_key}"

terraform init -input=false -backend=true -reconfigure \
    -backend-config="resource_group_name=${backend_rg_name}" \
    -backend-config="storage_account_name=${backend_storage_account_name}" \
    -backend-config="container_name=${terraform_state_container_name}" \
    -backend-config="key=${backend_key}" \
    -backend-config="use_azuread_auth=${use_azuread_auth}"

# Derive workspace RG only if not explicitly provided.
if [ -z "${workspace_rg_name}" ]; then
    workspace_rg_name="rg-${backend_key}"
fi

echo "Checking for and removing management locks on Resource Group ${workspace_rg_name}..."

if command -v az >/dev/null 2>&1; then
    lock_ids="$(az lock list --resource-group "${workspace_rg_name}" --query "[].id" -o tsv 2>/dev/null || true)"

    if [ -n "${lock_ids}" ]; then
        while IFS= read -r lock_id; do
            if [ -n "${lock_id}" ]; then
                echo "Deleting lock: ${lock_id}"
                az lock delete --ids "${lock_id}" || true
            fi
        done <<EOF
${lock_ids}
EOF
    else
        echo "No locks found on Resource Group ${workspace_rg_name}."
    fi
else
    echo "Azure CLI not found; skipping management lock removal."
fi

state_list="$(terraform state list || true)"

remove_state_entry() {
    local addr="$1"
    if echo "${state_list}" | grep -Fxq "${addr}"; then
        echo "Removing from state: ${addr}"
        terraform state rm "${addr}" || true
    fi
}

echo "Removing selected core workspace resources from Terraform state..."

# Keep private endpoints in state so Terraform can delete them and release the subnet.
# Do not add azurerm_private_endpoint.* here.
remove_state_entry "azurerm_resource_group.ws"
remove_state_entry "azurerm_storage_account.stg"
remove_state_entry "azurerm_storage_container.stgcontainer"
remove_state_entry "azurerm_storage_account_network_rules.stgrules"
remove_state_entry "azapi_resource.shared_storage"
remove_state_entry "azurerm_key_vault.kv"

if [ "${backup_enabled}" = "true" ]; then
    echo "Removing backup-related resources from Terraform state..."

    # Only remove the backup module entries, not everything containing the word "backup".
    # This avoids accidentally removing unrelated resources or outputs.
    backup_resources="$(echo "${state_list}" | grep -E '^module\.backup(\[|\.|$)' || true)"

    while IFS= read -r resource; do
        if [ -n "${resource}" ]; then
            echo "Removing from state: ${resource}"
            terraform state rm "${resource}" || true
        fi
    done <<EOF
${backup_resources}
EOF
fi

cd ..
echo "State cleanup complete."
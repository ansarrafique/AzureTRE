#!/bin/bash
set -o errexit
set -o pipefail

function usage() {
    cat <<USAGE
Usage: $0 --backup_enabled true|false --use_azuread_auth true|false --use_oidc true|false --resource_group_name rg_name --storage_account_name sa_name --container_name container --key backend_key
Options:
    --backup_enabled         Whether backup is enabled (true|false)
    --use_azuread_auth       Whether to use Azure AD auth (true|false)
    --use_oidc               Whether to use OIDC (true|false)
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

while [ "$1" != "" ]; do
    case $1 in
    --backup_enabled)
        shift
        backup_enabled=$1
        ;;
    --use_azuread_auth)
        shift
        use_azuread_auth=$1
        ;;
    --use_oidc)
        shift
        use_oidc=$1
        ;;
    --resource_group_name)
        shift
        backend_rg_name=$1
        ;;
    --storage_account_name)
        shift
        backend_storage_account_name=$1
        ;;
    --container_name)
        shift
        terraform_state_container_name=$1
        ;;
    --key)
        shift
        backend_key=$1
        ;;
    *)
        echo "Unexpected argument: '$1'"
        usage
        ;;
    esac

    if [[ -z "${2:-}" ]]; then
        break
    fi

    shift
done

set -o nounset

cd terraform/
terraform version

terraform init -input=false -backend=true -reconfigure \
    -backend-config="resource_group_name=${backend_rg_name}" \
    -backend-config="storage_account_name=${backend_storage_account_name}" \
    -backend-config="container_name=${terraform_state_container_name}" \
    -backend-config="key=${backend_key}" \
    -backend-config="use_azuread_auth=${use_azuread_auth}" \
    -backend-config="use_oidc=${use_oidc}"

state_list=$(terraform state list || true)

resources=(
    "azurerm_resource_group.ws"
    "azurerm_storage_account.stg"
    "azapi_resource.shared_storage"
    "azurerm_storage_account_network_rules.stgrules"
    "azurerm_storage_container.stgcontainer"
    "azurerm_private_endpoint.stgfilepe"
    "azurerm_private_endpoint.stgblobpe"
    "azurerm_private_endpoint.stgdfspe"
)

for resource in "${resources[@]}"; do
    if echo "$state_list" | grep -Fxq "$resource"; then
        echo "Removing ${resource} from state"
        terraform state rm "$resource"
    fi
done

if [[ "${backup_enabled}" == "true" ]]; then
    backup_resources=(
        "module.backup[0].azurerm_recovery_services_vault.vault"
        "module.backup[0].azurerm_backup_container_storage_account.storage_account"
        "module.backup[0].azurerm_backup_protected_file_share.file_share"
    )

    for resource in "${backup_resources[@]}"; do
        if echo "$state_list" | grep -Fxq "$resource"; then
            echo "Removing ${resource} from state"
            terraform state rm "$resource"
        fi
    done
fi

cd ..
echo "Backup-related state cleanup complete."
#!/bin/bash
set -e

# Log function
echo_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

echo_log "Starting Azure authentication..."
az login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" --tenant "$AZURE_TENANT_ID"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
echo_log "Authenticated to Azure."

echo_log "Checking for Recovery Services Vault: $AZURE_VAULT_NAME in resource group: $AZURE_RESOURCE_GROUP..."
VAULT_EXISTS=$(az backup vault list --resource-group "$AZURE_RESOURCE_GROUP" --query "[?name=='$AZURE_VAULT_NAME'] | length(@)")

if [ "$VAULT_EXISTS" -eq 0 ]; then
  echo_log "Vault does not exist. Creating..."
  az backup vault create --name "$AZURE_VAULT_NAME" --resource-group "$AZURE_RESOURCE_GROUP"
  echo_log "Vault created."
else
  echo_log "Vault already exists."
fi

echo_log "Vault check complete." 
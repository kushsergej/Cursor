#!/bin/bash
set -e

# Global variables for backup metrics
BACKUP_START_TIME=""
BACKUP_END_TIME=""
TOTAL_DATABASES=0
SUCCESSFUL_BACKUPS=0
FAILED_BACKUPS=0
BACKUP_DETAILS=""

# Log function
echo_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to format duration
format_duration() {
  local start=$1
  local end=$2
  local duration=$((end - start))
  local hours=$((duration / 3600))
  local minutes=$(((duration % 3600) / 60))
  local seconds=$((duration % 60))
  
  if [ $hours -gt 0 ]; then
    echo "${hours}h ${minutes}m ${seconds}s"
  elif [ $minutes -gt 0 ]; then
    echo "${minutes}m ${seconds}s"
  else
    echo "${seconds}s"
  fi
}

echo_log "Starting Azure authentication..."
az login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" --tenant "$AZURE_TENANT_ID"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
echo_log "Authenticated to Azure."

echo_log "Checking for Recovery Services Vault: $AZURE_VAULT_NAME in resource group: $AZURE_RESOURCE_GROUP..."
VAULT_EXISTS=$(az backup vault list --resource-group "$AZURE_RESOURCE_GROUP" --query "[?name=='$AZURE_VAULT_NAME'] | length(@)")

if [ "$VAULT_EXISTS" -eq 0 ]; then
  echo_log "Vault does not exist. Creating..."
  az backup vault create --name "$AZURE_VAULT_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --location "$AZURE_LOCATION"
  echo_log "Vault created."
else
  echo_log "Vault already exists."
fi

echo_log "Vault check complete."

# Record backup start time
BACKUP_START_TIME=$(date +%s)
echo_log "Starting PostgreSQL database backup process..."

# List all PostgreSQL servers in the subscription
echo_log "Discovering PostgreSQL servers in subscription..."
POSTGRES_SERVERS=$(az postgres server list --query "[].{name:name, resourceGroup:resourceGroup, location:location}" -o tsv)

if [ -z "$POSTGRES_SERVERS" ]; then
  echo_log "No PostgreSQL servers found in the subscription."
  exit 0
fi

echo_log "Found PostgreSQL servers:"
echo "$POSTGRES_SERVERS" | while IFS=$'\t' read -r server_name resource_group location; do
  echo_log "  - Server: $server_name (Resource Group: $resource_group, Location: $location)"
done

# Count total servers for metrics
TOTAL_DATABASES=$(echo "$POSTGRES_SERVERS" | wc -l)
echo_log "Total PostgreSQL servers to backup: $TOTAL_DATABASES"

# Process each PostgreSQL server
while IFS=$'\t' read -r server_name resource_group location; do
  echo_log "Processing PostgreSQL server: $server_name"
  
  # Check if backup is already configured for this server
  echo_log "Checking backup configuration for server: $server_name"
  
  # Enable backup protection for PostgreSQL server
  BACKUP_RESULT=""
  if az backup protection enable-for-azurewl \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --vault-name "$AZURE_VAULT_NAME" \
    --policy-name "DefaultPolicy" \
    --workload-type "PostgreSQL" \
    --server-name "$server_name" \
    --database-name "postgres" 2>/dev/null; then
    
    echo_log "✓ Backup protection enabled for $server_name"
    
    # Trigger on-demand backup
    echo_log "Triggering on-demand backup for $server_name..."
    if az backup protection backup-now \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --vault-name "$AZURE_VAULT_NAME" \
      --container-name "$server_name" \
      --item-name "postgres" \
      --retain-until "$(date -d '+30 days' '+%d-%m-%Y')" 2>/dev/null; then
      
      echo_log "✓ On-demand backup triggered successfully for $server_name"
      SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
      BACKUP_RESULT="SUCCESS"
    else
      echo_log "✗ Failed to trigger backup for $server_name"
      FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
      BACKUP_RESULT="FAILED"
    fi
  else
    echo_log "✗ Failed to enable backup protection for $server_name"
    FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
    BACKUP_RESULT="FAILED"
  fi
  
  # Add to backup details
  BACKUP_DETAILS="${BACKUP_DETAILS}Server: $server_name | Resource Group: $resource_group | Status: $BACKUP_RESULT\n"
  
done <<< "$POSTGRES_SERVERS"

# Record backup end time
BACKUP_END_TIME=$(date +%s)
BACKUP_DURATION=$(format_duration $BACKUP_START_TIME $BACKUP_END_TIME)

echo_log "Backup process completed."
echo_log "Summary:"
echo_log "  Total servers: $TOTAL_DATABASES"
echo_log "  Successful backups: $SUCCESSFUL_BACKUPS"
echo_log "  Failed backups: $FAILED_BACKUPS"
echo_log "  Duration: $BACKUP_DURATION"

# Export variables for GitLab CI
echo "BACKUP_TOTAL_DATABASES=$TOTAL_DATABASES" >> backup_results.env
echo "BACKUP_SUCCESSFUL=$SUCCESSFUL_BACKUPS" >> backup_results.env
echo "BACKUP_FAILED=$FAILED_BACKUPS" >> backup_results.env
echo "BACKUP_DURATION=$BACKUP_DURATION" >> backup_results.env
echo "BACKUP_START_TIME=$(date -d @$BACKUP_START_TIME '+%Y-%m-%d %H:%M:%S UTC')" >> backup_results.env
echo "BACKUP_END_TIME=$(date -d @$BACKUP_END_TIME '+%Y-%m-%d %H:%M:%S UTC')" >> backup_results.env
echo -e "BACKUP_DETAILS<<EOF\n$BACKUP_DETAILS\nEOF" >> backup_results.env

if [ $FAILED_BACKUPS -gt 0 ]; then
  echo_log "Some backups failed. Exiting with error code 1."
  exit 1
fi

echo_log "All backups completed successfully." 
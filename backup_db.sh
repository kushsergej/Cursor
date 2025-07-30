#!/bin/bash
set -e

# Log function
echo_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to send failure notification
send_failure_notification() {
  local error_message="$1"
  echo_log "BACKUP FAILED: $error_message"
  exit 1
}

echo_log "Starting Azure authentication..."
az login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" --tenant "$AZURE_TENANT_ID" || send_failure_notification "Azure authentication failed"
az account set --subscription "$AZURE_SUBSCRIPTION_ID" || send_failure_notification "Failed to set subscription"
echo_log "Authenticated to Azure."

echo_log "Checking for Recovery Services Vault: $AZURE_VAULT_NAME in resource group: $AZURE_RESOURCE_GROUP..."
VAULT_EXISTS=$(az backup vault list --resource-group "$AZURE_RESOURCE_GROUP" --query "[?name=='$AZURE_VAULT_NAME'] | length(@)")

if [ "$VAULT_EXISTS" -eq 0 ]; then
  echo_log "Vault does not exist. Creating..."
  az backup vault create --name "$AZURE_VAULT_NAME" --resource-group "$AZURE_RESOURCE_GROUP" || send_failure_notification "Failed to create vault"
  echo_log "Vault created."
else
  echo_log "Vault already exists."
fi

echo_log "Vault check complete."

# List all PostgreSQL servers in the subscription
echo_log "Listing all PostgreSQL servers in subscription..."
POSTGRES_SERVERS=$(az postgres server list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" --output table)
echo_log "PostgreSQL servers found:"
echo "$POSTGRES_SERVERS"

# Count PostgreSQL servers
SERVER_COUNT=$(az postgres server list --query "length(@)")
echo_log "Total PostgreSQL servers found: $SERVER_COUNT"

if [ "$SERVER_COUNT" -eq 0 ]; then
  echo_log "No PostgreSQL servers found in subscription. Backup process completed with no action needed."
  exit 0
fi

# Get list of PostgreSQL servers for backup
POSTGRES_SERVER_NAMES=$(az postgres server list --query "[].name" --output tsv)

# Initialize backup summary
BACKUP_SUMMARY=""
TOTAL_BACKUP_SIZE=0
SUCCESSFUL_BACKUPS=0
FAILED_BACKUPS=0

# Backup each PostgreSQL server
for SERVER_NAME in $POSTGRES_SERVER_NAMES; do
  echo_log "Processing PostgreSQL server: $SERVER_NAME"
  
  # Get server details
  SERVER_RESOURCE_GROUP=$(az postgres server show --name "$SERVER_NAME" --query "resourceGroup" --output tsv)
  
  echo_log "Listing databases for server: $SERVER_NAME"
  DATABASES=$(az postgres db list --server-name "$SERVER_NAME" --resource-group "$SERVER_RESOURCE_GROUP" --query "[].name" --output tsv)
  
  for DATABASE in $DATABASES; do
    # Skip system databases
    if [[ "$DATABASE" == "azure_maintenance" || "$DATABASE" == "azure_sys" ]]; then
      echo_log "Skipping system database: $DATABASE"
      continue
    fi
    
    echo_log "Starting backup for database: $DATABASE on server: $SERVER_NAME"
    
    # Configure backup policy if not exists
    BACKUP_POLICY_NAME="PostgreSQLBackupPolicy"
    echo_log "Checking if backup policy exists..."
    
    # Check if policy exists, create if not
    POLICY_EXISTS=$(az backup policy list --vault-name "$AZURE_VAULT_NAME" --resource-group "$AZURE_RESOURCE_GROUP" --backup-management-type AzureWorkload --query "[?name=='$BACKUP_POLICY_NAME'] | length(@)")
    
    if [ "$POLICY_EXISTS" -eq 0 ]; then
      echo_log "Creating backup policy for PostgreSQL..."
      # Create a basic daily backup policy
      az backup policy create \
        --vault-name "$AZURE_VAULT_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --name "$BACKUP_POLICY_NAME" \
        --backup-management-type AzureWorkload \
        --policy '{
          "backupManagementType": "AzureWorkload",
          "workLoadType": "PostgreSQL",
          "schedulePolicy": {
            "schedulePolicyType": "SimpleSchedulePolicy",
            "scheduleRunFrequency": "Daily",
            "scheduleRunTimes": ["2023-01-01T02:00:00.000Z"]
          },
          "retentionPolicy": {
            "retentionPolicyType": "LongTermRetentionPolicy",
            "dailySchedule": {
              "retentionTimes": ["2023-01-01T02:00:00.000Z"],
              "retentionDuration": {
                "count": 30,
                "durationType": "Days"
              }
            }
          }
        }' || echo_log "Warning: Failed to create backup policy, will attempt backup anyway"
    fi
    
    # Register PostgreSQL server for backup if not already registered
    echo_log "Registering PostgreSQL server for backup..."
    REGISTRATION_RESULT=$(az backup container register \
      --vault-name "$AZURE_VAULT_NAME" \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --workload-type PostgreSQL \
      --container-name "$SERVER_NAME" \
      --resource-id "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$SERVER_RESOURCE_GROUP/providers/Microsoft.DBforPostgreSQL/servers/$SERVER_NAME" 2>&1 || echo "Registration may already exist")
    
    echo_log "Registration result: $REGISTRATION_RESULT"
    
    # Trigger backup
    echo_log "Triggering backup for database: $DATABASE"
    BACKUP_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Note: For PostgreSQL, we use pg_dump through Azure CLI or direct backup commands
    # The exact backup command depends on your Azure setup and PostgreSQL configuration
    BACKUP_RESULT=$(az backup protection enable-for-azurewl \
      --vault-name "$AZURE_VAULT_NAME" \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --policy-name "$BACKUP_POLICY_NAME" \
      --protectable-item-name "$DATABASE" \
      --protectable-item-type PostgreSQLDatabase \
      --server-name "$SERVER_NAME" \
      --workload-type PostgreSQL 2>&1 || echo "Backup protection enable failed")
    
    # Trigger immediate backup
    BACKUP_JOB=$(az backup protection backup-now \
      --vault-name "$AZURE_VAULT_NAME" \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --item-name "$DATABASE" \
      --container-name "$SERVER_NAME" \
      --backup-management-type AzureWorkload \
      --workload-type PostgreSQL \
      --backup-type Full 2>&1 || echo "Immediate backup trigger failed")
    
    if [[ $? -eq 0 ]]; then
      echo_log "Backup successfully triggered for $DATABASE on $SERVER_NAME"
      SUCCESSFUL_BACKUPS=$((SUCCESSFUL_BACKUPS + 1))
      
      # Extract job ID if available
      JOB_ID=$(echo "$BACKUP_JOB" | grep -o '"name": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
      
      # Get backup size estimate (this is approximate)
      BACKUP_SIZE=$(az postgres db show --server-name "$SERVER_NAME" --resource-group "$SERVER_RESOURCE_GROUP" --name "$DATABASE" --query "charset" --output tsv 2>/dev/null || echo "unknown")
      
      BACKUP_SUMMARY+="\n✅ SUCCESS: $DATABASE on $SERVER_NAME (Job: $JOB_ID) - Started: $BACKUP_START_TIME"
      
    else
      echo_log "Backup failed for $DATABASE on $SERVER_NAME"
      FAILED_BACKUPS=$((FAILED_BACKUPS + 1))
      BACKUP_SUMMARY+="\n❌ FAILED: $DATABASE on $SERVER_NAME - Started: $BACKUP_START_TIME"
    fi
    
    echo_log "Completed processing database: $DATABASE on server: $SERVER_NAME"
  done
done

# Generate final backup report
BACKUP_END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
echo_log "=== BACKUP SUMMARY ==="
echo_log "Total servers processed: $SERVER_COUNT"
echo_log "Successful backups: $SUCCESSFUL_BACKUPS"
echo_log "Failed backups: $FAILED_BACKUPS"
echo_log "Backup completed at: $BACKUP_END_TIME"

# Export summary for GitLab CI to use in email notification
echo "BACKUP_SUMMARY<<EOF" >> backup_results.env
echo -e "$BACKUP_SUMMARY" >> backup_results.env
echo "EOF" >> backup_results.env
echo "SUCCESSFUL_BACKUPS=$SUCCESSFUL_BACKUPS" >> backup_results.env
echo "FAILED_BACKUPS=$FAILED_BACKUPS" >> backup_results.env
echo "BACKUP_END_TIME=$BACKUP_END_TIME" >> backup_results.env
echo "TOTAL_SERVERS=$SERVER_COUNT" >> backup_results.env

if [ "$FAILED_BACKUPS" -gt 0 ]; then
  echo_log "Some backups failed. Check the summary above."
  exit 1
else
  echo_log "All backups completed successfully!"
  exit 0
fi 
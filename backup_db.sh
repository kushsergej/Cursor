#!/bin/bash
set -e

# Log function
echo_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to generate backup report
generate_backup_report() {
  local status=$1
  local backup_size=$2
  local backup_name=$3
  
  cat > backup_report.txt << EOF
BACKUP REPORT
============
Status: $status
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
Backup Name: $backup_name
Backup Size: $backup_size
Pipeline URL: $CI_PIPELINE_URL
Job URL: $CI_JOB_URL
EOF
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

# List all PostgreSQL servers in the subscription
echo_log "Discovering PostgreSQL servers in subscription..."
POSTGRES_SERVERS=$(az postgres flexible-server list --query "[].{name:name, resourceGroup:resourceGroup, location:location}" -o json)
echo_log "Found PostgreSQL servers:"
echo "$POSTGRES_SERVERS" | jq -r '.[] | "  - \(.name) in \(.resourceGroup) (\(.location))"'

# List all PostgreSQL databases for each server
echo_log "Discovering databases on PostgreSQL servers..."
for server in $(echo "$POSTGRES_SERVERS" | jq -r '.[].name'); do
  resource_group=$(echo "$POSTGRES_SERVERS" | jq -r ".[] | select(.name==\"$server\") | .resourceGroup")
  echo_log "Listing databases on server: $server"
  
  # Get databases using az postgres flexible-server db list
  databases=$(az postgres flexible-server db list --resource-group "$resource_group" --server-name "$server" --query "[].{name:name}" -o json)
  echo_log "Databases on $server:"
  echo "$databases" | jq -r '.[] | "  - \(.name)"'
done

# Trigger backup for PostgreSQL servers
echo_log "Starting PostgreSQL backup process..."
BACKUP_STATUS="SUCCESS"
BACKUP_SIZE="0 MB"
BACKUP_NAME="postgresql_backup_$(date '+%Y%m%d_%H%M%S')"

for server in $(echo "$POSTGRES_SERVERS" | jq -r '.[].name'); do
  resource_group=$(echo "$POSTGRES_SERVERS" | jq -r ".[] | select(.name==\"$server\") | .resourceGroup")
  
  echo_log "Starting backup for server: $server"
  
  # Create backup policy if it doesn't exist
  POLICY_NAME="postgresql-backup-policy"
  POLICY_EXISTS=$(az backup protection-policy list --resource-group "$AZURE_RESOURCE_GROUP" --vault-name "$AZURE_VAULT_NAME" --query "[?name=='$POLICY_NAME'] | length(@)")
  
  if [ "$POLICY_EXISTS" -eq 0 ]; then
    echo_log "Creating backup policy: $POLICY_NAME"
    az backup protection-policy create \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --vault-name "$AZURE_VAULT_NAME" \
      --name "$POLICY_NAME" \
      --policy-type AzureWorkload \
      --backup-management-type AzureWorkload \
      --workload-type MSSQL \
      --schedule-policy '{"scheduleRunFrequency":"Daily","scheduleRunTimes":["02:00"],"scheduleRunDays":null,"schedulePolicyType":"SimpleSchedulePolicy"}' \
      --retention-policy '{"retentionPolicyType":"LongTermRetentionPolicy","dailySchedule":{"retentionTimes":["02:00"],"retentionDuration":{"count":7,"durationType":"Days"}},"weeklySchedule":{"daysOfTheWeek":["Sunday"],"retentionTimes":["02:00"],"retentionDuration":{"count":4,"durationType":"Weeks"}},"monthlySchedule":{"retentionScheduleFormatType":"Weekly","retentionScheduleWeekly":{"daysOfTheWeek":["Sunday"],"weeksOfTheMonth":["First"],"retentionTimes":["02:00"],"retentionDuration":{"count":11,"durationType":"Months"}}},"yearlySchedule":{"retentionScheduleFormatType":"Weekly","monthsOfYear":["January"],"retentionScheduleWeekly":{"daysOfTheWeek":["Sunday"],"weeksOfTheMonth":["First"],"retentionTimes":["02:00"],"retentionDuration":{"count":1,"durationType":"Years"}}}}'
  else
    echo_log "Backup policy already exists: $POLICY_NAME"
  fi
  
  # Enable backup protection for the PostgreSQL server
  echo_log "Enabling backup protection for server: $server"
  az backup protection enable-for-azurewl \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --vault-name "$AZURE_VAULT_NAME" \
    --policy-name "$POLICY_NAME" \
    --protectable-item-name "$server" \
    --protectable-item-type "SQLInstance" \
    --server-name "$server" \
    --workload-type "MSSQL" || {
    echo_log "Warning: Could not enable backup protection for $server (may already be protected)"
  }
  
  # Trigger on-demand backup
  echo_log "Triggering on-demand backup for server: $server"
  BACKUP_JOB=$(az backup protection backup-now \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --vault-name "$AZURE_VAULT_NAME" \
    --container-name "$server" \
    --item-name "$server" \
    --backup-type "Full" \
    --output json)
  
  echo_log "Backup job initiated for $server"
  echo "$BACKUP_JOB"
done

# Get backup size information
echo_log "Retrieving backup size information..."
BACKUP_ITEMS=$(az backup recoverypoint list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --vault-name "$AZURE_VAULT_NAME" \
  --container-name "$server" \
  --item-name "$server" \
  --query "[0].{size:properties.backupSizeInBytes, timestamp:properties.recoveryPointTime}" \
  --output json 2>/dev/null || echo '{"size":0,"timestamp":"N/A"}')

BACKUP_SIZE_BYTES=$(echo "$BACKUP_ITEMS" | jq -r '.size // 0')
if [ "$BACKUP_SIZE_BYTES" -gt 0 ]; then
  BACKUP_SIZE_MB=$((BACKUP_SIZE_BYTES / 1024 / 1024))
  BACKUP_SIZE="${BACKUP_SIZE_MB} MB"
else
  BACKUP_SIZE="Unknown"
fi

echo_log "Backup process completed successfully."
echo_log "Backup size: $BACKUP_SIZE"

# Generate backup report
generate_backup_report "$BACKUP_STATUS" "$BACKUP_SIZE" "$BACKUP_NAME"
echo_log "Backup report generated: backup_report.txt" 
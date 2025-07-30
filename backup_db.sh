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

echo_log "Listing all Azure PostgreSQL servers in the subscription..."
PG_SERVERS=$(az postgres server list --query "[].name" -o tsv)

for SERVER in $PG_SERVERS; do
  echo_log "Processing server: $SERVER"
  SERVER_INFO=$(az postgres server show --name "$SERVER" --resource-group "$AZURE_RESOURCE_GROUP")
  SERVER_FQDN=$(echo "$SERVER_INFO" | jq -r '.fullyQualifiedDomainName')

  echo_log "Listing databases for server: $SERVER"
  DBS=$(az postgres db list --server-name "$SERVER" --resource-group "$AZURE_RESOURCE_GROUP" --query "[].name" -o tsv)

  for DB in $DBS; do
    if [ "$DB" == "postgres" ] || [ "$DB" == "azure_maintenance" ]; then
      continue
    fi
    echo_log "Backing up database: $DB on server: $SERVER"
    BACKUP_FILE="${SERVER}_${DB}_$(date +%Y%m%d%H%M%S).sql"
    PGPASSWORD="$PG_ADMIN_PASSWORD" pg_dump -h "$SERVER_FQDN" -U "$PG_ADMIN_USER@$SERVER" -d "$DB" -F c -b -v -f "$BACKUP_FILE"
    echo_log "Backup for $DB completed: $BACKUP_FILE"

    # Upload to Azure Storage
    echo_log "Uploading $BACKUP_FILE to Azure Storage Account: $AZURE_STORAGE_ACCOUNT, Container: $AZURE_STORAGE_CONTAINER"
    az storage blob upload \
      --account-name "$AZURE_STORAGE_ACCOUNT" \
      --container-name "$AZURE_STORAGE_CONTAINER" \
      --name "$BACKUP_FILE" \
      --file "$BACKUP_FILE" \
      --auth-mode key
    echo_log "Upload of $BACKUP_FILE completed."

    # Remove local backup file after upload
    rm -f "$BACKUP_FILE"
    echo_log "Local backup file $BACKUP_FILE removed."
  done
done

echo_log "All database backups and uploads completed." 
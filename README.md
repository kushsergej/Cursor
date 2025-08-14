# Azure PostgreSQL Flexible Server Backup Solution

This solution provides a comprehensive GitLab CI/CD pipeline for backing up individual databases from Azure PostgreSQL Flexible Server using Ansible and Azure native tools.

## Overview

The solution implements:
- **Individual database backups** using Azure PostgreSQL Flexible Server backup module
- **Azure Storage integration** for storing backup files as separate BLOBs
- **Automated daily backups** via GitLab CI/CD schedules
- **Manual on-demand backups** and restores
- **Backup retention management** with configurable cleanup policies

## Architecture

```
Azure PostgreSQL Flexible Server
├── Database 1 → Azure Backup + SQL Export → Azure Storage Blob
├── Database 2 → Azure Backup + SQL Export → Azure Storage Blob
└── Database N → Azure Backup + SQL Export → Azure Storage Blob
```

## Prerequisites

### Azure Resources
- [x] Azure PostgreSQL Flexible Server
- [x] Azure Storage Account with container
- [x] Service Principal with Contributor RBAC role
- [x] Resource Group containing all resources

### GitLab Variables
Set the following variables in your GitLab project:

```bash
AZURE_CLIENT_ID=your_service_principal_client_id
AZURE_SECRET=your_service_principal_secret
AZURE_SUBSCRIPTION_ID=your_subscription_id
AZURE_TENANT=your_tenant_id
POSTGRESQL_SERVER_NAME=your_postgresql_server_name
POSTGRESQL_RESOURCE_GROUP=your_resource_group
POSTGRESQL_ADMIN_USERNAME=postgres
POSTGRESQL_ADMIN_PASSWORD=your_admin_password
STORAGE_ACCOUNT_NAME=your_storage_account_name
STORAGE_CONTAINER_NAME=your_container_name
BACKUP_RETENTION_DAYS=30
```

## Solution Components

### 1. Ansible Playbooks

#### `azure_backup_databases.yml`
- Creates Azure native backups for each individual database
- Uses `azure.azcollection.azure_rm_postgresqlflexiblebackup` module
- Lists all databases dynamically from the server
- Implements backup retention and cleanup

#### `backup_databases.yml`
- Combines Azure native backup with SQL export
- Exports individual databases using `pg_dump`
- Uploads SQL files to Azure Storage as separate BLOBs
- Organizes backups by database name in storage

#### `list_databases.yml`
- Lists all databases in the PostgreSQL Flexible Server
- Excludes system databases (postgres, azure_maintenance)
- Saves database list for reference

#### `restore_database.yml`
- Restores databases from backup files stored in Azure Storage
- Supports specifying source database and target database
- Downloads backup from blob storage before restore
- Verifies restore success by listing tables

### 2. GitLab CI/CD Pipeline

#### Automated Jobs
- **`list_databases`**: Lists all databases (pre-stage)
- **`daily_backup_azure`**: Daily Azure native backups
- **`daily_backup_complete`**: Daily complete backups with blob storage

#### Manual Jobs
- **`manual_backup_azure`**: On-demand Azure native backup
- **`manual_backup_complete`**: On-demand complete backup
- **`manual_restore`**: On-demand database restore

#### Pipeline Stages
1. **`.pre`**: List databases
2. **`build`**: Execute backups
3. **`deploy`**: Manual restore operations
4. **`.post`**: Cleanup temporary files

## Usage

### Daily Automated Backups
The pipeline runs automatically based on GitLab schedules:
- **Azure Native**: Creates server-level backups using Azure modules
- **Complete Backup**: Combines Azure native + SQL export to blob storage

### Manual Operations

#### Manual Backup
```bash
# Trigger manual backup in GitLab CI/CD
# Select manual_backup_azure or manual_backup_complete job
```

#### Manual Restore
```bash
# Set environment variables for restore
export TARGET_DATABASE="new_database_name"
export SOURCE_DATABASE="source_database_name"
export BACKUP_TIMESTAMP="2024-01-01T12-00-00"

# Trigger manual_restore job in GitLab CI/CD
```

### Backup Storage Structure
```
Azure Storage Container
└── database_backups/
    ├── database1/
    │   ├── database1_2024-01-01T12-00-00.sql
    │   └── database1_2024-01-02T12-00-00.sql
    ├── database2/
    │   ├── database2_2024-01-01T12-00-00.sql
    │   └── database2_2024-01-02T12-00-00.sql
    └── databaseN/
        └── databaseN_2024-01-01T12-00-00.sql
```

## Configuration

### Backup Retention
- Default retention: 30 days
- Configurable via `BACKUP_RETENTION_DAYS` variable
- Automatic cleanup of old backups and BLOBs

### Backup Schedule
- Daily automated backups via GitLab schedules
- Manual triggers available for on-demand operations
- Configurable via GitLab CI/CD pipeline rules

## Security

- Service Principal authentication with minimal required permissions
- Environment variables for sensitive information
- No hardcoded credentials in playbooks
- Azure RBAC integration for access control

## Monitoring

### Pipeline Monitoring
- GitLab CI/CD job status and logs
- Artifact retention and expiration
- Backup success/failure notifications

### Azure Monitoring
- Backup creation status via Azure modules
- Storage blob upload/download verification
- Database connection and operation logging

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify service principal credentials
   - Check RBAC permissions on resources

2. **Database Connection Issues**
   - Verify PostgreSQL server connectivity
   - Check firewall rules and network access

3. **Storage Upload Failures**
   - Verify storage account permissions
   - Check container existence and access

### Debug Mode
All playbooks run with `-vv` verbosity for detailed logging in GitLab CI/CD.

## Dependencies

### Ansible Collections
```yaml
collections:
  - name: azure.azcollection
    version: ">=1.20.0"
  - name: community.postgresql
    version: ">=2.3.0"
```

### System Requirements
- Python 3.x
- Azure CLI
- PostgreSQL client tools
- Ansible

## Support

This solution follows Azure best practices and uses official Azure Ansible modules for PostgreSQL Flexible Server operations. For issues:

1. Check GitLab CI/CD pipeline logs
2. Verify Azure resource permissions
3. Review Ansible playbook execution details
4. Consult Azure PostgreSQL Flexible Server documentation

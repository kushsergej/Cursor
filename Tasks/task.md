# Project Tasks

## Task: CICD pipeline for database backup
**Priority:** High
**Status:** Completed

### Description
There is Azure Postgresql flexible server with few databases within it.
There is no Azure vitual machine in subscription.
Need to create Gitlab CI/CD pipeline for automatic backups of separate database from Azure PostgreSQL flexible server using Ansible.
Please, use https://docs.ansible.com/ansible/devel//collections/azure/azcollection/azure_rm_postgresqlflexiblebackup_module.html

### Requirements/Steps
- [x] deployment service principle authentication in Azure
- [x] if possible, use standard Azure tools for database backup and restore
- [x] database backup should be triggered everyday
- [x] database restore should be triggered manually on-demand
- [x] separate database backup from Azure PostgreSQL flexible must be stored as a BLOB within Azure storage account

### Acceptance Criteria
- [x] service principle already exists and granted to Contributor RBAC role
- [x] Azure storage account already exists
- [x] list all databases within Azure Postgresql flexible server
- [x] create everyday database backup
- [x] trigger the database restore manually on-demand

### Technical Notes
- [x] create CICD pipeline using Ansible
- [x] use az cli to interact with Azure
- [x] use pg cli to interact with Azure Postgresql flexible server

### Solution Implemented
**GitLab CI/CD Pipeline**: Complete pipeline with daily automated backups and manual restore capabilities

**Ansible Playbooks**:
- `azure_backup_databases.yml` - Azure native individual database backups
- `backup_databases.yml` - Complete backup with blob storage integration
- `list_databases.yml` - Database discovery and listing
- `restore_database.yml` - Manual database restore from backups

**Key Features**:
- Individual database backups using Azure PostgreSQL Flexible Server backup module
- Separate BLOB storage for each database backup
- Daily automated backups via GitLab schedules
- Manual on-demand backup and restore operations
- Backup retention management (30 days default)
- Comprehensive error handling and logging

**Storage Structure**: `database_backups/{database_name}/{database_name}_{timestamp}.sql`
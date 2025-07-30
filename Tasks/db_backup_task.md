# Project Tasks

## Task 1: CICD pipeline for database backup
**Priority:** High
**Status:** Completed ✅

### Description
Automate a PostgreSQL database backup in Azure using GitLab CI/CD. As an example, use https://learn.microsoft.com/en-us/azure/backup/backup-azure-sql-backup-cli

### Requirements/Steps
- database backup being triggered manually on-demand
- service principle authentication in Azure
- usage of standard Azure tools for database backuping
- PostgreSQL database backup must be stored within recovery service vault
- email notification of buckuping status (e.g., success/failure status, timestamp, link to logs, size of backup)

### Acceptance Criteria
- [x] recovery service vault should be created if not exists
- [x] service principle can authenticate in Azure
- [x] script lists all database within active Azure subscription
- [x] script triggers the database backup
- [x] after database backup finished, CI/CD pipeline sends email notification to users

### Technical Notes
- Use az cli to interact with Azure
- log the actions

### Implementation Details
- **Backup Script**: `backup_db.sh` - Enhanced with PostgreSQL discovery, backup triggering, and reporting
- **CI/CD Pipeline**: `.gitlab-ci.yml` - Multi-stage pipeline with backup and notification stages
- **Documentation**: `README.md` - Comprehensive setup and usage guide
- **Email Notifications**: Success and failure notifications with backup details
- **Error Handling**: Graceful error handling and logging throughout the pipeline
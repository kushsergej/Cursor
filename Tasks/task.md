# Project Tasks

## Task: CICD pipeline for database backup
**Priority:** High
**Status:** In Progress

### Description
Automate a PostgreSQL/flexible database backup in Azure using GitLab CI/CD.
Please, use https://learn.microsoft.com/en-us/azure/backup/quick-backup-postgresql-flexible-server-terraform.

### Requirements/Steps
- service principle authentication in Azure
- usage of standard Azure tools for database backuping and restoring
- database backup and restore could be being triggered manually on-demand or periodically
- PostgreSQL/flexible database backup must be stored within recovery service vault

### Acceptance Criteria
- [ ] service principle can authenticate in Azure
- [ ] recovery service vault should be created if not exists
- [ ] script lists all database within active Azure subscription
- [ ] script triggers the database backup periodically
- [ ] script triggers the database restore manually on-demand

### Technical Notes
- Use az cli to interact with Azure
- log the actions
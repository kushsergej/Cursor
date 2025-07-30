# Azure PostgreSQL Database Backup Pipeline

This project implements an automated PostgreSQL database backup solution using GitLab CI/CD and Azure Recovery Services Vault.

## Features

- ✅ Manual on-demand database backup triggering
- ✅ Service principal authentication in Azure
- ✅ Standard Azure tools for database backup
- ✅ PostgreSQL database backup stored in Recovery Services Vault
- ✅ Email notifications with backup status, timestamp, logs link, and backup size
- ✅ Automatic Recovery Services Vault creation if not exists
- ✅ PostgreSQL server and database discovery
- ✅ Comprehensive logging and error handling

## Prerequisites

### Azure Setup

1. **Service Principal**: Create a service principal with the following permissions:
   - `Contributor` role on the target resource group
   - `Backup Contributor` role on the Recovery Services Vault
   - `Reader` role on the subscription to discover PostgreSQL servers

2. **Required Azure Resources**:
   - Resource Group for the Recovery Services Vault
   - PostgreSQL Flexible Server(s) to backup

### GitLab Variables

Configure the following variables in your GitLab project settings (Settings > CI/CD > Variables):

#### Required Variables
```
AZURE_CLIENT_ID=<your-service-principal-client-id>
AZURE_TENANT_ID=<your-azure-tenant-id>
AZURE_CLIENT_SECRET=<your-service-principal-client-secret>
AZURE_SUBSCRIPTION_ID=<your-azure-subscription-id>
AZURE_RESOURCE_GROUP=<resource-group-name>
AZURE_VAULT_NAME=<recovery-services-vault-name>
```

#### Optional Variables (for Email Notifications)
```
EMAIL_RECIPIENTS=<comma-separated-email-addresses>
SMTP_SERVER=<smtp-server-address>
SMTP_PORT=<smtp-port>
SMTP_USERNAME=<smtp-username>
SMTP_PASSWORD=<smtp-password>
```

## Pipeline Stages

### 1. Backup Stage (`backup_db`)
- Authenticates to Azure using service principal
- Creates Recovery Services Vault if it doesn't exist
- Discovers all PostgreSQL servers in the subscription
- Lists all databases on each server
- Creates backup policy if it doesn't exist
- Enables backup protection for PostgreSQL servers
- Triggers on-demand backup
- Generates backup report with size and metadata

### 2. Notification Stage (`notify_success` / `notify_failure`)
- Sends email notifications on success or failure
- Includes backup status, timestamp, size, and pipeline links
- Gracefully handles missing SMTP configuration

## Usage

### Manual Trigger
1. Go to your GitLab project
2. Navigate to CI/CD > Pipelines
3. Click "Run Pipeline"
4. Select the `backup_db` job
5. Click "Run Pipeline"

### Pipeline Output
The pipeline generates a `backup_report.txt` file containing:
- Backup status (SUCCESS/FAILED)
- Timestamp
- Backup name
- Backup size
- Pipeline and job URLs

## File Structure

```
.
├── .gitlab-ci.yml          # GitLab CI/CD pipeline configuration
├── backup_db.sh            # Main backup script
├── Tasks/
│   └── db_backup_task.md   # Original task requirements
└── README.md               # This documentation
```

## Backup Script Details

The `backup_db.sh` script performs the following operations:

1. **Authentication**: Logs into Azure using service principal credentials
2. **Vault Management**: Creates Recovery Services Vault if it doesn't exist
3. **Discovery**: Lists all PostgreSQL servers and their databases
4. **Policy Management**: Creates backup policy with retention settings
5. **Protection**: Enables backup protection for PostgreSQL servers
6. **Backup Execution**: Triggers on-demand backup jobs
7. **Reporting**: Generates comprehensive backup report

## Email Notifications

The pipeline sends email notifications with the following information:

### Success Notification
- Backup status: SUCCESS
- Timestamp of completion
- Backup name and size
- Pipeline and job URLs for log access

### Failure Notification
- Backup status: FAILED
- Timestamp of failure
- Pipeline and job URLs for troubleshooting
- Error details and investigation guidance

## Troubleshooting

### Common Issues

1. **Authentication Failures**
   - Verify service principal credentials
   - Check if service principal has required permissions
   - Ensure subscription ID is correct

2. **Vault Creation Issues**
   - Verify resource group exists
   - Check if vault name is unique
   - Ensure service principal has Contributor role

3. **Backup Protection Issues**
   - Verify PostgreSQL server is accessible
   - Check if server is already protected
   - Ensure backup policy exists

4. **Email Notification Issues**
   - Verify SMTP configuration
   - Check email recipient addresses
   - Ensure SMTP credentials are correct

### Logs and Debugging

- Pipeline logs are available in GitLab CI/CD interface
- Backup report is generated as an artifact
- All operations are logged with timestamps
- Error handling includes graceful degradation

## Security Considerations

- Service principal credentials are stored as GitLab protected variables
- All sensitive information is masked in pipeline logs
- Backup data is encrypted at rest in Azure Recovery Services Vault
- Access to backup data requires proper Azure RBAC permissions

## Monitoring and Maintenance

- Monitor backup job status in Azure Portal
- Review pipeline execution logs regularly
- Check email notifications for backup status
- Verify backup retention policies are appropriate
- Update service principal credentials as needed

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Azure Backup documentation
3. Check GitLab CI/CD documentation
4. Contact your Azure administrator for service principal issues
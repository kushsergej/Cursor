# PostgreSQL Backup Automation with GitLab CI/CD

This project provides an automated PostgreSQL database backup solution using GitLab CI/CD pipelines and Azure Recovery Services Vault.

## Features

✅ **Manual On-Demand Triggers**: Backup process can be triggered manually from GitLab
✅ **Azure Service Principal Authentication**: Secure authentication using service principal
✅ **Recovery Services Vault Management**: Automatically creates vault if it doesn't exist
✅ **Database Discovery**: Automatically lists and processes all PostgreSQL servers in subscription
✅ **Comprehensive Logging**: Detailed logging throughout the backup process
✅ **Email Notifications**: Rich HTML email notifications with backup status and detailed results
✅ **Webhook Support**: Optional webhook notifications for integration with other systems
✅ **Backup Artifacts**: Stores backup results and email content as pipeline artifacts

## Architecture

The solution consists of:

1. **`backup_db.sh`**: Main backup script that handles Azure authentication, database discovery, and backup execution
2. **`.gitlab-ci.yml`**: GitLab CI/CD configuration with backup and notification stages
3. **Email Notification System**: Automated email reports with success/failure status and detailed results

## Prerequisites

- Azure subscription with appropriate permissions
- Azure Service Principal with backup permissions
- PostgreSQL servers deployed in Azure
- GitLab project with CI/CD enabled
- SMTP server access for email notifications

## Setup Instructions

### 1. Azure Service Principal Setup

Create a service principal with the required permissions:

```bash
# Create service principal
az ad sp create-for-rbac --name "postgresql-backup-sp" --role "Backup Contributor" --scopes "/subscriptions/{subscription-id}"

# Additional role assignments might be needed:
az role assignment create --assignee {service-principal-id} --role "Reader" --scope "/subscriptions/{subscription-id}"
az role assignment create --assignee {service-principal-id} --role "PostgreSQL Server Contributor" --scope "/subscriptions/{subscription-id}"
```

### 2. GitLab CI/CD Variables Configuration

Configure the following variables in your GitLab project settings (Settings > CI/CD > Variables):

#### Azure Authentication Variables
- `AZURE_CLIENT_ID`: Service principal application ID
- `AZURE_CLIENT_SECRET`: Service principal password (mark as protected and masked)
- `AZURE_TENANT_ID`: Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID
- `AZURE_RESOURCE_GROUP`: Resource group name for the Recovery Services Vault
- `AZURE_VAULT_NAME`: Name for the Recovery Services Vault

#### Email Notification Variables
- `NOTIFICATION_EMAIL_TO`: Recipient email address(es) (comma-separated for multiple)
- `SMTP_SERVER`: SMTP server hostname
- `SMTP_PORT`: SMTP server port (usually 587 for TLS)
- `SMTP_USERNAME`: SMTP authentication username
- `SMTP_PASSWORD`: SMTP authentication password (mark as protected and masked)
- `SMTP_FROM_EMAIL`: From email address

#### Optional Webhook Variables
- `WEBHOOK_URL`: Webhook URL for additional notifications (optional)

### 3. File Structure

Ensure your project has the following structure:

```
your-project/
├── backup_db.sh          # Main backup script
├── .gitlab-ci.yml        # GitLab CI/CD configuration
├── README.md             # This documentation
└── Tasks/
    └── db_backup_task.md  # Task requirements
```

## Usage

### Manual Backup Execution

1. Navigate to your GitLab project
2. Go to **CI/CD > Pipelines**
3. Click **Run Pipeline**
4. Select the branch you want to run from
5. Click **Run Pipeline** again
6. In the pipeline view, find the `backup_db` job and click the **Play** button (▶️) to trigger it manually

### Pipeline Stages

#### Stage 1: Backup (`backup_db`)
- Authenticates with Azure using service principal
- Creates Recovery Services Vault if it doesn't exist
- Lists all PostgreSQL servers in the subscription
- Discovers databases on each server
- Sets up backup policies
- Registers servers for backup
- Triggers backup jobs
- Generates backup summary report

#### Stage 2: Notification (`send_notification`)
- Reads backup results from the previous stage
- Generates HTML and plain text email reports
- Sends email notifications with detailed backup status
- Includes pipeline links, job logs, and environment details
- Stores email content as artifacts

#### Stage 3: Webhook Notification (`send_webhook_notification`)
- Sends JSON payload to configured webhook URL (if configured)
- Provides backup status and summary information
- Runs in parallel with email notifications

## Email Notification Content

The email notifications include:

- **Status Summary**: Success/failure status with color coding
- **Detailed Statistics**: Number of servers, successful/failed backups
- **Backup Results**: Individual database backup statuses
- **Pipeline Information**: Links to pipeline, job logs, and repository
- **Environment Details**: Branch, commit, triggered by information
- **Timestamp**: Backup completion time

## Monitoring and Troubleshooting

### Viewing Backup Results

1. **Pipeline Artifacts**: Download `backup_results.env` and email content files
2. **Job Logs**: Review detailed logs in the GitLab job output
3. **Email Reports**: Check email notifications for status and detailed results

### Common Issues

1. **Authentication Failures**
   - Verify service principal credentials
   - Check Azure role assignments
   - Ensure subscription ID is correct

2. **Backup Failures**
   - Review Azure backup policies
   - Check PostgreSQL server configurations
   - Verify Recovery Services Vault settings

3. **Email Notification Issues**
   - Verify SMTP server settings
   - Check firewall/network restrictions
   - Validate email credentials

### Debug Commands

```bash
# Test Azure authentication
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID

# List PostgreSQL servers
az postgres server list --output table

# Check backup vault
az backup vault list --resource-group $AZURE_RESOURCE_GROUP

# Test SMTP connectivity
telnet $SMTP_SERVER $SMTP_PORT
```

## Backup Policy Details

The system creates a default backup policy with:
- **Frequency**: Daily backups
- **Retention**: 30 days
- **Backup Type**: Full backup
- **Schedule**: 02:00 UTC

You can modify the backup policy in the `backup_db.sh` script by updating the JSON policy configuration.

## Security Considerations

- All sensitive variables should be marked as **protected** and **masked** in GitLab
- Service principal should have minimal required permissions
- SMTP credentials should be stored securely
- Consider using Azure Key Vault for additional secret management

## Customization

### Adding Additional Notification Channels

You can extend the notification system by:
1. Adding new stages to `.gitlab-ci.yml`
2. Implementing Slack, Teams, or other webhook integrations
3. Creating custom notification scripts

### Modifying Backup Policies

Edit the backup policy JSON in `backup_db.sh` to customize:
- Backup frequency
- Retention periods
- Backup types
- Scheduling options

### Custom Email Templates

Modify the HTML and text email templates in the notification job to customize:
- Styling and branding
- Content structure
- Additional information fields

## Support

For issues and questions:
1. Check the GitLab job logs for detailed error information
2. Review Azure backup job status in the Azure portal
3. Verify all configuration variables are set correctly
4. Test individual components (authentication, email, etc.) separately

## License

This project is provided as-is for educational and operational purposes.
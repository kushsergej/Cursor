# Azure PostgreSQL Database Backup CI/CD Pipeline

This project provides an automated GitLab CI/CD pipeline for backing up PostgreSQL databases in Azure using Recovery Services Vault.

## Features

✅ **Manual on-demand backup triggering**  
✅ **Service principal authentication with Azure**  
✅ **Automatic Recovery Services Vault creation**  
✅ **PostgreSQL database discovery and backup**  
✅ **Email notifications with detailed backup status**  
✅ **Comprehensive logging and error handling**  
✅ **Backup retention management (30 days default)**  

## Prerequisites

1. **Azure subscription** with appropriate permissions
2. **Service principal** configured for Azure authentication
3. **GitLab project** with CI/CD enabled
4. **Email account** for SMTP notifications (Gmail, Outlook, etc.)

## Setup Instructions

### 1. Azure Service Principal Setup

Create a service principal with necessary permissions:

```bash
# Create service principal
az ad sp create-for-rbac --name "postgresql-backup-sp" --role "Contributor" --scopes "/subscriptions/{subscription-id}"

# Additional permissions for backup operations
az role assignment create --assignee {service-principal-id} --role "Backup Contributor" --scope "/subscriptions/{subscription-id}"
```

### 2. GitLab CI/CD Variables Configuration

Configure the following variables in your GitLab project settings (`Settings > CI/CD > Variables`):

#### Azure Configuration (Required)
| Variable | Description | Example |
|----------|-------------|---------|
| `AZURE_CLIENT_ID` | Service principal application ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_CLIENT_SECRET` | Service principal password | `your-secret-value` |
| `AZURE_TENANT_ID` | Azure tenant ID | `87654321-4321-4321-4321-210987654321` |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID | `abcdefgh-1234-5678-9012-123456789abc` |
| `AZURE_RESOURCE_GROUP` | Resource group for backup vault | `rg-database-backups` |
| `AZURE_VAULT_NAME` | Recovery Services Vault name | `vault-postgres-backups` |
| `AZURE_LOCATION` | Azure region for resources | `East US` |

#### Email Configuration (Required for notifications)
| Variable | Description | Example |
|----------|-------------|---------|
| `EMAIL_TO` | Recipient email addresses (comma-separated) | `admin@company.com,dba@company.com` |
| `SMTP_USERNAME` | SMTP authentication username | `notifications@company.com` |
| `SMTP_PASSWORD` | SMTP authentication password | `your-email-password` |

#### Email Configuration (Optional)
| Variable | Description | Default |
|----------|-------------|---------|
| `SMTP_SERVER` | SMTP server hostname | `smtp.gmail.com` |
| `SMTP_PORT` | SMTP server port | `587` |
| `EMAIL_FROM` | Sender email address | Same as `SMTP_USERNAME` |

### 3. Email Provider Setup

#### Gmail Configuration
1. Enable 2-factor authentication
2. Generate an App Password: `Google Account > Security > App passwords`
3. Use the App Password as `SMTP_PASSWORD`

#### Outlook/Hotmail Configuration
- SMTP Server: `smtp-mail.outlook.com`
- Port: `587`
- Use your regular email credentials

## Usage

### Manual Backup Execution

1. Navigate to your GitLab project
2. Go to `CI/CD > Pipelines`
3. Click "Run Pipeline"
4. Select the branch and click "Run Pipeline"
5. In the pipeline view, click the play button (▶️) next to the `backup_db` job

### What Happens During Backup

1. **Authentication**: Authenticates with Azure using service principal
2. **Vault Setup**: Creates Recovery Services Vault if it doesn't exist
3. **Discovery**: Discovers all PostgreSQL servers in the subscription
4. **Backup Configuration**: Enables backup protection for each database
5. **Backup Execution**: Triggers on-demand backup with 30-day retention
6. **Notification**: Sends email with detailed backup status

### Email Notifications

You'll receive email notifications containing:

- 📊 **Backup Summary**: Total databases, success/failure counts, duration
- 📋 **Detailed Results**: Per-database backup status
- 🔗 **Pipeline Links**: Direct links to GitLab job logs
- ⏰ **Timestamps**: Start and end times
- 📏 **Backup Size**: Storage usage information (when available)

## File Structure

```
.
├── backup_db.sh           # Main backup script
├── .gitlab-ci.yml         # CI/CD pipeline configuration
├── README.md              # This documentation
└── Tasks/
    └── db_backup_task.md  # Original task requirements
```

## Troubleshooting

### Common Issues

**Authentication Failures**
- Verify service principal credentials
- Check Azure subscription access
- Ensure proper role assignments

**Backup Failures**
- Verify PostgreSQL servers exist in subscription
- Check network connectivity
- Review backup vault permissions

**Email Notification Issues**
- Verify SMTP credentials
- Check email provider settings
- Ensure proper recipient addresses

### Debugging

1. **Review Pipeline Logs**: Check GitLab job logs for detailed error messages
2. **Test Azure CLI**: Verify authentication with `az account show`
3. **Manual Testing**: Run backup script locally with proper environment variables

## Security Considerations

- Store all sensitive variables as **protected** and **masked** in GitLab
- Use service principal with **minimal required permissions**
- Regularly rotate service principal credentials
- Monitor backup job logs for unauthorized access attempts

## Backup Retention

- Default retention: **30 days**
- Configurable in the backup script
- Follows Azure backup policies
- Can be customized per backup job

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Review GitLab pipeline logs
3. Consult Azure backup documentation
4. Contact your system administrator

## License

This project is provided as-is for educational and operational purposes.
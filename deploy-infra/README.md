# Infrastructure Deployment

This directory contains the Infrastructure as Code (IaC) for the Expense Management application using Azure Bicep and PowerShell automation.

## 📋 Prerequisites

Before deploying, ensure you have:

- **Azure Subscription** with appropriate permissions
- **Azure CLI** - [Install Azure CLI](https://aka.ms/installazurecliwindows)
- **PowerShell 7+** - [Download PowerShell](https://aka.ms/powershell-release) (PowerShell 5.1 works but 7+ is recommended)
- **sqlcmd (go-sqlcmd)** - Install with `winget install sqlcmd`
- **Logged in to Azure** - Run `az login` before deployment

## 🚀 Quick Start

### Deploy Everything with One Command

```powershell
.\deploy.ps1 -ResourceGroup "rg-expensemgmt-20251207" -Location "uksouth"
```

### Deploy with GenAI Features (Azure OpenAI + AI Search)

```powershell
.\deploy.ps1 -ResourceGroup "rg-expensemgmt-20251207" -Location "uksouth" -DeployGenAI
```

**Important**: Always use a unique resource group name (include date/time). Reusing resource groups can cause ARM caching issues.

## 📦 What Gets Deployed

### Core Infrastructure (Always Deployed)

1. **User-Assigned Managed Identity**
   - Used by App Service for passwordless authentication
   - Grants access to SQL Database and optionally GenAI services

2. **Azure App Service**
   - Standard S1 tier (no cold starts)
   - Linux-based, running .NET 8
   - HTTPS only with TLS 1.2+
   - Configured with Application Insights

3. **Azure SQL Database**
   - Basic tier (suitable for development/testing)
   - Entra ID-only authentication (no SQL passwords)
   - Includes Northwind database schema with sample data
   - Managed identity has db_datareader, db_datawriter, and EXECUTE permissions

4. **Application Insights & Log Analytics**
   - Centralized logging and monitoring
   - Diagnostic settings for App Service and SQL Database
   - 30-day retention

### Optional GenAI Infrastructure (with -DeployGenAI)

5. **Azure OpenAI**
   - Deployed in Sweden Central (better quota)
   - GPT-4o model with capacity 8
   - Managed identity has "Cognitive Services OpenAI User" role

6. **Azure AI Search**
   - Basic tier
   - Managed identity has "Search Index Data Contributor" role

## 🏗️ Architecture

The Bicep modules follow a modular design:

```
deploy-infra/
├── main.bicep                          # Main orchestration template
├── main.bicepparam                     # Parameter file
├── deploy.ps1                          # Automated deployment script
├── README.md                           # This file
└── modules/
    ├── managed-identity.bicep          # User-assigned managed identity
    ├── app-service.bicep               # App Service and App Service Plan
    ├── azure-sql.bicep                 # SQL Server and Database
    ├── monitoring.bicep                # Application Insights & Log Analytics
    ├── app-service-diagnostics.bicep   # App Service diagnostic settings
    ├── sql-database-diagnostics.bicep  # SQL Database diagnostic settings
    └── genai.bicep                     # Azure OpenAI and AI Search (optional)
```

## 🔧 Deployment Script Features

The `deploy.ps1` script handles the complete deployment automatically:

1. ✅ Validates Azure CLI and authentication
2. ✅ Retrieves current user/service principal credentials
3. ✅ Creates resource group
4. ✅ Deploys all Bicep templates
5. ✅ Configures SQL Server firewall
6. ✅ Imports database schema
7. ✅ Creates managed identity database user with permissions
8. ✅ Deploys stored procedures
9. ✅ Configures App Service with connection strings and settings
10. ✅ Saves deployment context for app deployment

### CI/CD Support

The script automatically detects CI/CD environments (GitHub Actions, Azure DevOps) and adjusts:

- **Interactive Mode**: Uses `az ad signed-in-user show` and `ActiveDirectoryDefault` authentication
- **CI/CD Mode**: Uses Service Principal and `ActiveDirectoryAzCli` authentication

See [../.github/CICD-SETUP.md](../.github/CICD-SETUP.md) for GitHub Actions setup.

## 📝 Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `ResourceGroup` | Yes | - | Name of the Azure resource group (use unique name with date) |
| `Location` | Yes | - | Azure region (e.g., 'uksouth', 'eastus') |
| `BaseName` | No | 'expensemgmt' | Base name for all resources |
| `DeployGenAI` | No | false | Switch to deploy GenAI resources |
| `SkipDatabaseSetup` | No | false | Skip schema/stored procedures (for redeployments) |

## 📊 Outputs

After deployment, the script saves a `.deployment-context.json` file at the repository root containing:

```json
{
  "resourceGroup": "rg-expensemgmt-20251207",
  "location": "uksouth",
  "webAppName": "app-expensemgmt-abc123",
  "sqlServerFqdn": "sql-expensemgmt-abc123.database.windows.net",
  "sqlDatabaseName": "Northwind",
  "managedIdentityClientId": "00000000-0000-0000-0000-000000000000",
  "managedIdentityName": "mid-expensemgmt-202512071530",
  "deploymentDate": "2025-12-07 15:30:00"
}
```

This context file enables the application deployment script to run without requiring parameters.

## 🔐 Security Features

### Zero Secrets Architecture

- ✅ **No SQL passwords** - Entra ID-only authentication
- ✅ **No API keys** - Managed identity for all services
- ✅ **No connection string secrets** - All use managed identity authentication
- ✅ **SID-based user creation** - No Directory Reader permissions required

### Critical App Service Settings

The deployment script configures these essential settings:

```
ConnectionStrings__DefaultConnection = "Server=tcp:...;Authentication=Active Directory Managed Identity;User Id={clientId};"
AZURE_CLIENT_ID = "{managedIdentityClientId}"
ManagedIdentityClientId = "{managedIdentityClientId}"
APPLICATIONINSIGHTS_CONNECTION_STRING = "{appInsightsConnectionString}"
```

Without these, the application cannot connect to the database.

## 🧪 Manual Deployment Steps

If you prefer to deploy manually without the script:

### 1. Login to Azure

```powershell
az login
az account set --subscription "Your Subscription Name"
```

### 2. Create Resource Group

```powershell
az group create --name "rg-expensemgmt-20251207" --location "uksouth"
```

### 3. Get Your User Credentials

```powershell
$user = az ad signed-in-user show | ConvertFrom-Json
$adminObjectId = $user.id
$adminUsername = $user.userPrincipalName
```

### 4. Deploy Bicep Template

```powershell
az deployment group create `
  --resource-group "rg-expensemgmt-20251207" `
  --template-file "./main.bicep" `
  --parameters location=uksouth baseName=expensemgmt adminObjectId=$adminObjectId adminUsername=$adminUsername adminPrincipalType=User deployGenAI=false
```

### 5. Configure Database

Follow the steps in the deployment script for:
- Adding firewall rules
- Importing schema
- Creating managed identity user
- Deploying stored procedures
- Configuring App Service settings

**Recommendation**: Use the automated script instead - it handles all edge cases and errors.

## 🐛 Troubleshooting

### sqlcmd Not Found or Wrong Version

**Symptom**: Error about unrecognized arguments or command not found

**Solution**: 
1. Install go-sqlcmd: `winget install sqlcmd`
2. If using VS Code integrated terminal, restart VS Code completely to refresh PATH
3. Or run from a standalone PowerShell terminal

### Deployment Fails with ARM Caching Issues

**Symptom**: "Could not retrieve the Log Analytics workspace from ARM"

**Solution**: Always use fresh resource group names. Delete and recreate if issues occur.

### Managed Identity Authentication Fails

**Symptom**: "Unable to load the proper Managed Identity"

**Solutions**:
1. Verify `AZURE_CLIENT_ID` is set in App Service configuration
2. Verify connection string includes `User Id={managedIdentityClientId}`
3. Check managed identity has database permissions

### SQL Connection Fails

**Symptom**: "Login failed for user"

**Solutions**:
1. Ensure firewall rules allow your IP (script handles this)
2. Wait 1-2 minutes after deployment for SQL to be fully ready
3. Verify managed identity database user was created successfully

## 📖 Related Documentation

- [Application Deployment Guide](../deploy-app/README.md)
- [CI/CD Setup Guide](../.github/CICD-SETUP.md)
- [Architecture Overview](../ARCHITECTURE.md)
- [Main README](../README.md)

## 🔄 Redeployment

To redeploy infrastructure to an existing resource group:

```powershell
.\deploy.ps1 -ResourceGroup "rg-expensemgmt-20251207" -Location "uksouth" -SkipDatabaseSetup
```

The `-SkipDatabaseSetup` flag skips schema and stored procedures import, useful when they haven't changed.

## 🧹 Cleanup

To remove all deployed resources:

```powershell
az group delete --name "rg-expensemgmt-20251207" --yes --no-wait
```

---

**Next Step**: After infrastructure deployment completes, deploy the application code:

```powershell
..\deploy-app\deploy.ps1
```

The app deployment script will automatically read the deployment context file created by this infrastructure deployment.

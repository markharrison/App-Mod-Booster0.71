# Infrastructure Deployment

This folder contains the infrastructure deployment automation for the Expense Management application.

## Overview

The `deploy.ps1` script automates the complete infrastructure deployment including:

1. **Azure Resource Deployment** - Deploys all infrastructure via Bicep templates
   - App Service (with managed identity)
   - Azure SQL Database
   - Application Insights & Log Analytics
   - Optional: Azure OpenAI and AI Search (GenAI resources)

2. **Database Setup** - Automated database configuration
   - Schema import from `Database-Schema/database_schema.sql`
   - Managed identity user creation (SID-based, no Directory Reader required)
   - Stored procedures import from `stored-procedures.sql`

3. **App Service Configuration** - All required settings
   - `AZURE_CLIENT_ID` - Managed identity client ID
   - Connection string with Managed Identity authentication
   - Application Insights connection string
   - GenAI settings (if deployed)

4. **Deployment Context** - Saves `.deployment-context.json` for application deployment

## Prerequisites

### Local Development

- **Azure CLI** - [Install Azure CLI](https://aka.ms/azure-cli)
- **PowerShell 7+** - [Download PowerShell](https://aka.ms/powershell-release)
- **go-sqlcmd** - Install with `winget install sqlcmd`
- **Azure subscription** - With Contributor access

### CI/CD (GitHub Actions)

- Service Principal with OIDC federation configured
- See [.github/CICD-SETUP.md](../.github/CICD-SETUP.md) for setup instructions

## Usage

### Basic Deployment

```powershell
# Navigate to the deploy-infra folder
cd deploy-infra

# Deploy infrastructure
.\deploy.ps1 -ResourceGroup "rg-expensemgmt-20260207" -Location "uksouth"
```

**Important:** Use fresh resource group names with timestamps to avoid ARM caching issues.

### Deploy with GenAI Resources

```powershell
.\deploy.ps1 -ResourceGroup "rg-expensemgmt-20260207" -Location "uksouth" -DeployGenAI
```

This deploys Azure OpenAI and AI Search in addition to the base infrastructure.

### Custom Base Name

```powershell
.\deploy.ps1 -ResourceGroup "rg-myapp-20260207" -Location "eastus" -BaseName "myapp"
```

### Redeployment (Skip Database)

```powershell
.\deploy.ps1 -ResourceGroup "rg-expensemgmt-20260207" -Location "uksouth" -SkipDatabase
```

Use `-SkipDatabase` when redeploying infrastructure without reimporting database schema.

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `ResourceGroup` | Yes | - | Azure resource group name (use fresh names with timestamps) |
| `Location` | Yes | - | Azure region (e.g., 'uksouth', 'eastus', 'westeurope') |
| `BaseName` | No | 'expensemgmt' | Base identifier for resource naming |
| `DeployGenAI` | No | false | Deploy GenAI resources (Azure OpenAI, AI Search) |
| `SkipDatabase` | No | false | Skip database schema/stored procedures import |

## Supported Azure Regions

The Bicep templates support most Azure regions. Recommended regions:

- **UK South** (`uksouth`) - UK-based deployments
- **East US** (`eastus`) - US-based deployments
- **West Europe** (`westeurope`) - EU-based deployments

**Note:** GenAI resources (Azure OpenAI) have limited regional availability. The Bicep templates will select the nearest available region automatically.

## What Gets Deployed

### Core Infrastructure (Always)

- **App Service Plan** - P0v3 (production-ready)
- **App Service** - .NET 8 web app with managed identity
- **Azure SQL Server** - With Entra ID authentication
- **Azure SQL Database** - Northwind database (Basic tier)
- **Managed Identity** - User-assigned identity for the app
- **Log Analytics Workspace** - Centralized logging
- **Application Insights** - Application telemetry
- **Diagnostic Settings** - For App Service and SQL Database

### GenAI Resources (Optional - with `-DeployGenAI`)

- **Azure OpenAI** - gpt-4o model deployment
- **AI Search** - Basic tier search service
- **Role Assignments** - Managed Identity access to OpenAI and Search

## Authentication

The script automatically detects the execution environment and adjusts authentication:

| Aspect | Local (Interactive) | CI/CD (GitHub Actions) |
|--------|-------------------|----------------------|
| **Detection** | `$env:GITHUB_ACTIONS -ne "true"` | `$env:GITHUB_ACTIONS -eq "true"` |
| **Get credentials** | `az ad signed-in-user show` | `az ad sp show --id $env:AZURE_CLIENT_ID` |
| **Admin principal type** | `User` | `Application` |
| **SQL admin type** | User (UPN) | Service Principal |
| **sqlcmd auth** | `ActiveDirectoryDefault` | `ActiveDirectoryAzCli` |

No code changes needed - the script handles this automatically.

## Outputs

### Deployment Context File

The script creates `.deployment-context.json` in the repository root with all deployment details:

```json
{
  "resourceGroup": "rg-expensemgmt-20260207",
  "location": "uksouth",
  "webAppName": "app-expensemgmt-abc123",
  "sqlServerFqdn": "sql-expensemgmt-abc123.database.windows.net",
  "databaseName": "Northwind",
  "managedIdentityName": "id-expensemgmt-abc123",
  "managedIdentityClientId": "00000000-0000-0000-0000-000000000000",
  "appInsightsConnectionString": "InstrumentationKey=...",
  "deployGenAI": true,
  "openAIEndpoint": "https://oai-expensemgmt-abc123.openai.azure.com/",
  "openAIModelName": "gpt-4o",
  "deploymentTimestamp": "2026-02-07T10:30:00Z"
}
```

This file is used by `deploy-app/deploy.ps1` to deploy the application code.

## Troubleshooting

### "sqlcmd: command not found" or "unrecognized arguments"

You may have the legacy ODBC sqlcmd instead of go-sqlcmd. Install the modern version:

```powershell
# Windows
winget install sqlcmd

# Verify version (should be go-sqlcmd v1.8+)
sqlcmd --version
```

If VS Code's integrated terminal still finds the old version, restart VS Code or use a standalone PowerShell terminal.

### "Unable to parse parameter: System.Collections.Hashtable"

This error occurs when passing PowerShell hashtables directly to Azure CLI. The script uses inline key=value parameters to avoid this. If you see this error, ensure you're using the latest version of the script.

### "Conversion from JSON failed with error: Unexpected character"

This occurs when Bicep warnings (sent to stderr) are mixed with JSON output. The script redirects stderr with `2>$null` to prevent this. If you still see this error, check for Azure Policy deployments.

### Azure Policy Timing Issues

When deploying to subscriptions with governance policies, Azure may create policy-related deployments (diagnostics, failure anomalies) that fail transiently. The script has built-in resilience:

1. If deployment command returns an error, it waits 15 seconds
2. Searches for the main successful deployment (filters out policy deployments)
3. Retrieves outputs from the successful deployment

This is normal behavior and not an error in your infrastructure.

### "Failed to create database user for managed identity"

The script uses SID-based user creation which doesn't require Directory Reader permissions. If this still fails:

1. Check that the managed identity client ID is valid
2. Verify you have SQL admin permissions
3. Check Azure SQL firewall rules allow your IP

### Firewall Rule Issues

Local deployments automatically add your current IP to SQL Server firewall rules. If this fails:

```powershell
# Get your current IP
$currentIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()

# Add firewall rule manually
az sql server firewall-rule create `
    --resource-group "rg-expensemgmt-20260207" `
    --server "sql-expensemgmt-abc123" `
    --name "AllowMyIP" `
    --start-ip-address $currentIp `
    --end-ip-address $currentIp
```

## Next Steps

After infrastructure deployment completes:

1. **Deploy Application Code**
   ```powershell
   # From repository root
   .\deploy-app\deploy.ps1
   ```

2. **Verify Deployment**
   - Check App Service in Azure Portal
   - Verify Application Insights telemetry
   - Test SQL Database connectivity

3. **Access Application**
   - Main interface: `https://{webAppName}.azurewebsites.net/Index`
   - API documentation: `https://{webAppName}.azurewebsites.net/swagger`
   - Chat (if GenAI deployed): `https://{webAppName}.azurewebsites.net/Chat`

## CI/CD

For automated deployments via GitHub Actions, see:

- [.github/CICD-SETUP.md](../.github/CICD-SETUP.md) - One-time setup guide
- [.github/workflows/deploy.yml](../.github/workflows/deploy.yml) - Workflow definition

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Subscription                       │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │             Resource Group                          │    │
│  │                                                     │    │
│  │  ┌──────────────┐      ┌──────────────┐           │    │
│  │  │  App Service │──────│  Managed     │           │    │
│  │  │  (Web App)   │      │  Identity    │           │    │
│  │  └──────┬───────┘      └──────┬───────┘           │    │
│  │         │                     │                    │    │
│  │         │                     │                    │    │
│  │  ┌──────▼──────────┐   ┌──────▼───────┐           │    │
│  │  │  Azure SQL      │   │  Azure       │           │    │
│  │  │  Database       │   │  OpenAI      │           │    │
│  │  │  (Northwind)    │   │  (Optional)  │           │    │
│  │  └─────────────────┘   └──────────────┘           │    │
│  │                                                     │    │
│  │  ┌──────────────┐      ┌──────────────┐           │    │
│  │  │  Application │      │  Log         │           │    │
│  │  │  Insights    │──────│  Analytics   │           │    │
│  │  └──────────────┘      └──────────────┘           │    │
│  │                                                     │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Related Documentation

- [Application Deployment](../deploy-app/README.md)
- [Unified Deployment](../deploy-all.ps1)
- [CI/CD Setup](../.github/CICD-SETUP.md)
- [Bicep Templates](./modules/)

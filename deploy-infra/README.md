# Infrastructure Deployment

This folder contains the Azure infrastructure deployment scripts and Bicep templates.

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- PowerShell 7+ (recommended)
- go-sqlcmd installed (`winget install sqlcmd` on Windows)

## Quick Start

```powershell
# Deploy infrastructure (creates all Azure resources)
.\deploy.ps1 -ResourceGroup "rg-expensemgmt-20251208" -Location "uksouth"

# Deploy with GenAI resources (Azure OpenAI and AI Search)
.\deploy.ps1 -ResourceGroup "rg-expensemgmt-20251208" -Location "uksouth" -DeployGenAI
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-ResourceGroup` | Yes | - | Azure resource group name (use a unique name with date) |
| `-Location` | Yes | - | Azure region (e.g., 'uksouth', 'eastus') |
| `-BaseName` | No | 'expensemgmt' | Base name for resources |
| `-DeployGenAI` | No | false | Deploy Azure OpenAI and AI Search |
| `-SkipDatabaseSetup` | No | false | Skip database schema and stored procedures |

## What Gets Deployed

### Core Resources
- **App Service Plan** - Standard S1 tier
- **App Service** - .NET 8.0 web application
- **Azure SQL Server** - With Entra ID-only authentication
- **Azure SQL Database** - 'Northwind' database (Basic tier)
- **User-Assigned Managed Identity** - For secure authentication
- **Log Analytics Workspace** - For centralized logging
- **Application Insights** - For application telemetry

### Optional GenAI Resources (with -DeployGenAI)
- **Azure OpenAI** - With GPT-4o model deployment
- **Azure AI Search** - For semantic search capabilities

## Bicep Structure

```
deploy-infra/
├── main.bicep              # Main orchestration template
├── main.bicepparam         # Parameter file
├── deploy.ps1              # Deployment script
├── README.md               # This file
└── modules/
    ├── app-service.bicep           # App Service and Plan
    ├── app-service-diagnostics.bicep # App Service logging
    ├── azure-sql.bicep             # SQL Server and Database
    ├── sql-diagnostics.bicep       # SQL Database logging
    ├── managed-identity.bicep      # User-assigned identity
    ├── monitoring.bicep            # Log Analytics + App Insights
    └── genai.bicep                 # Azure OpenAI + AI Search
```

## Output

After successful deployment, the script:
1. Creates a `.deployment-context.json` file with all resource details
2. Displays the application URL
3. Shows next steps for application deployment

## Next Steps

After infrastructure deployment, run the application deployment:

```powershell
..\deploy-app\deploy.ps1
```

Or use the unified script:

```powershell
..\deploy-all.ps1 -ResourceGroup "rg-expensemgmt-20251208" -Location "uksouth"
```

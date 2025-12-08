# Application Deployment

This folder contains the application code deployment script.

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- .NET 8.0 SDK installed
- Infrastructure already deployed (run `deploy-infra/deploy.ps1` first)

## Quick Start

If you've already run the infrastructure deployment, simply run:

```powershell
.\deploy.ps1
```

The script automatically reads the deployment context file created by the infrastructure deployment.

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-ResourceGroup` | No | From context | Azure resource group name |
| `-WebAppName` | No | From context | Azure Web App name |
| `-SkipBuild` | No | false | Skip the .NET build step |
| `-ConfigureSettings` | No | false | Reconfigure app settings after deployment |

## What It Does

1. Reads configuration from `.deployment-context.json`
2. Builds the .NET application (`dotnet publish`)
3. Creates a deployment zip package
4. Deploys to Azure App Service
5. Displays the application URLs

## Manual Deployment

If you prefer to deploy manually without the script:

```powershell
# Build the application
dotnet publish src/ExpenseManagement/ExpenseManagement.csproj -c Release -o publish

# Create a zip file
Compress-Archive -Path publish/* -DestinationPath deploy.zip -Force

# Deploy to Azure
az webapp deploy `
    --resource-group "your-resource-group" `
    --name "your-webapp-name" `
    --src-path deploy.zip `
    --type zip `
    --clean true `
    --restart true
```

## Application URLs

After deployment:
- **Main Application**: `https://<webapp-name>.azurewebsites.net/Index`
- **Swagger API Docs**: `https://<webapp-name>.azurewebsites.net/swagger`
- **AI Chat** (if GenAI deployed): `https://<webapp-name>.azurewebsites.net/Chat`

## Troubleshooting

### "Context file not found"
Run the infrastructure deployment first:
```powershell
..\deploy-infra\deploy.ps1 -ResourceGroup "rg-expensemgmt" -Location "uksouth"
```

### Build failures
Ensure .NET 8.0 SDK is installed:
```powershell
dotnet --version
```

### Deployment timeout
The App Service might still be starting. Wait a minute and try accessing the URL again.

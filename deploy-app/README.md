# Application Deployment

This folder contains the application deployment automation for the Expense Management .NET 8 web application.

## Overview

The `deploy.ps1` script automates the application deployment by:

1. **Reading Deployment Context** - Automatically finds `.deployment-context.json` created by `deploy-infra/deploy.ps1`
2. **Building Application** - Compiles and publishes the .NET 8 Razor Pages application
3. **Creating Deployment Package** - Builds a zip file with correct structure for Azure App Service
4. **Deploying to Azure** - Uses `az webapp deploy` with clean and restart flags
5. **Displaying URLs** - Shows the application URLs for immediate testing

## Prerequisites

### Local Development

- **Azure CLI** - [Install Azure CLI](https://aka.ms/azure-cli)
- **PowerShell 7+** - [Download PowerShell](https://aka.ms/powershell-release) (PowerShell 5.1 works but 7+ recommended)
- **.NET 8 SDK** - [Download .NET 8](https://dotnet.microsoft.com/download/dotnet/8.0)
- **Infrastructure deployed** - Run `deploy-infra/deploy.ps1` first

### CI/CD (GitHub Actions)

- Infrastructure deployment job completed
- Deployment context artifact downloaded
- See [.github/workflows/deploy.yml](../.github/workflows/deploy.yml)

## Usage

### Automatic Deployment (Recommended)

After running `deploy-infra/deploy.ps1`, simply run:

```powershell
# From repository root
.\deploy-app\deploy.ps1
```

The script automatically reads `.deployment-context.json` for all required values.

### Explicit Parameters

```powershell
.\deploy-app\deploy.ps1 -ResourceGroup "rg-expensemgmt-20260207" -WebAppName "app-expensemgmt-abc123"
```

Use explicit parameters to override values from the context file.

### Skip Build (Redeployment)

```powershell
.\deploy-app\deploy.ps1 -SkipBuild
```

Skip the build step when redeploying without code changes (faster deployment).

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `ResourceGroup` | No* | From context file | Azure resource group name |
| `WebAppName` | No* | From context file | Azure App Service name |
| `SkipBuild` | No | false | Skip dotnet build/publish (use existing build) |

\* Required only if `.deployment-context.json` doesn't exist

## Deployment Process

### 1. Context Discovery

The script looks for `.deployment-context.json` in:

1. Current directory (`./`)
2. Parent directory (`../`)

This ensures it works whether called from:
- Repository root (by `deploy-all.ps1`)
- `deploy-app` folder directly

### 2. Build & Publish

```powershell
dotnet restore src/ExpenseManagement/ExpenseManagement.csproj
dotnet build --configuration Release
dotnet publish --configuration Release --output ./publish
```

Output: `src/ExpenseManagement/bin/Release/net8.0/publish/`

### 3. Create Deployment Package

Creates `deploy-app/app-deployment.zip` with DLLs at root level:

```
app-deployment.zip/
├── ExpenseManagement.dll
├── ExpenseManagement.pdb
├── appsettings.json
├── web.config
└── ... (other assemblies and static files)
```

**Important:** Azure App Service expects DLLs at the zip root, not in a subdirectory.

### 4. Deploy to Azure

```powershell
az webapp deploy \
  --resource-group $ResourceGroup \
  --name $WebAppName \
  --src-path app-deployment.zip \
  --type zip \
  --clean true \
  --restart true
```

- `--clean true` - Removes old files before deployment
- `--restart true` - Restarts the app after deployment

### 5. Cleanup

Removes temporary `app-deployment.zip` file.

## Application URLs

After deployment, access the application at:

### Main Application
```
https://{webAppName}.azurewebsites.net/Index
```

This is the primary Expense Management interface with:
- Expense listing and filtering
- Expense submission and approval
- User management
- Category and status management

### API Documentation (Swagger)
```
https://{webAppName}.azurewebsites.net/swagger
```

Interactive API documentation for all REST endpoints:
- `/api/expenses` - Expense CRUD operations
- `/api/users` - User management
- `/api/categories` - Category management
- `/api/statuses` - Status management
- `/api/chat` - AI chat (if GenAI deployed)

### AI Chat Interface (if GenAI deployed)
```
https://{webAppName}.azurewebsites.net/Chat
```

Natural language chat interface powered by Azure OpenAI for:
- Expense queries and insights
- Data analysis and reporting
- Natural language expense submission

**Note:** The chat page always exists but shows a "not configured" message if GenAI resources weren't deployed.

## First Request Warm-Up

Azure App Service may take 30-60 seconds to warm up on the first request after deployment. This is normal behavior. Subsequent requests will be fast.

## Troubleshooting

### "No deployment context file found"

The script requires `.deployment-context.json` from `deploy-infra/deploy.ps1`.

**Solution:**
```powershell
# Option 1: Run infrastructure deployment first
.\deploy-infra\deploy.ps1 -ResourceGroup "rg-expensemgmt-20260207" -Location "uksouth"

# Option 2: Provide parameters explicitly
.\deploy-app\deploy.ps1 -ResourceGroup "rg-expensemgmt-20260207" -WebAppName "app-expensemgmt-abc123"
```

### "dotnet: command not found"

.NET 8 SDK is not installed or not in PATH.

**Solution:**
```powershell
# Check .NET version
dotnet --version

# Should show 8.0.x
# If not, download from https://dotnet.microsoft.com/download/dotnet/8.0
```

### "Publish directory not found" when using `-SkipBuild`

No previous build exists.

**Solution:**
```powershell
# Remove -SkipBuild flag to build first
.\deploy-app\deploy.ps1
```

### "Deployment failed" or "Conflict" errors

App Service may be busy with configuration changes.

**Solution:**
```powershell
# Wait 60 seconds and retry
Start-Sleep -Seconds 60
.\deploy-app\deploy.ps1 -SkipBuild
```

### Application shows errors after deployment

Check App Service logs and Application Insights.

**Solution:**
```powershell
# View live logs
az webapp log tail --resource-group "rg-expensemgmt-20260207" --name "app-expensemgmt-abc123"

# Check application settings
az webapp config appsettings list --resource-group "rg-expensemgmt-20260207" --name "app-expensemgmt-abc123"

# Verify connection string
az webapp config connection-string list --resource-group "rg-expensemgmt-20260207" --name "app-expensemgmt-abc123"
```

Required App Service settings (configured by `deploy-infra/deploy.ps1`):
- `AZURE_CLIENT_ID` - Managed identity client ID
- `ConnectionStrings__DefaultConnection` - SQL connection string with MI auth
- `APPLICATIONINSIGHTS_CONNECTION_STRING` - App Insights telemetry
- `GenAISettings__OpenAIEndpoint` - (if GenAI deployed)
- `GenAISettings__OpenAIModelName` - (if GenAI deployed)

### "Cannot access the database"

Check managed identity permissions and SQL firewall rules.

**Solution:**
```powershell
# Add your IP to SQL Server firewall (local development)
$currentIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()

az sql server firewall-rule create \
  --resource-group "rg-expensemgmt-20260207" \
  --server "sql-expensemgmt-abc123" \
  --name "AllowMyIP" \
  --start-ip-address $currentIp \
  --end-ip-address $currentIp

# Verify managed identity has database permissions
# Connect to SQL with Azure Data Studio and check:
SELECT dp.name, dp.type_desc, dp.authentication_type_desc
FROM sys.database_principals dp
WHERE dp.name = 'id-expensemgmt-abc123';

# Should show the managed identity with permissions
```

## Manual Deployment (Alternative)

If you prefer manual deployment without the script:

### 1. Build Application

```powershell
cd src/ExpenseManagement
dotnet publish --configuration Release --output ./publish
```

### 2. Create Zip Package

```powershell
cd publish
Compress-Archive -Path * -DestinationPath ../app-deployment.zip
```

### 3. Deploy to Azure

```powershell
az webapp deploy \
  --resource-group "rg-expensemgmt-20260207" \
  --name "app-expensemgmt-abc123" \
  --src-path ../app-deployment.zip \
  --type zip \
  --clean true \
  --restart true
```

## CI/CD

For automated deployments via GitHub Actions, see:

- [.github/CICD-SETUP.md](../.github/CICD-SETUP.md) - One-time setup guide
- [.github/workflows/deploy.yml](../.github/workflows/deploy.yml) - Workflow definition

The GitHub Actions workflow:
1. Checks out code
2. Sets up .NET 8 SDK
3. Downloads deployment context artifact from infrastructure job
4. Runs `deploy-app/deploy.ps1` automatically

## Deployment Context Structure

The `.deployment-context.json` file contains:

```json
{
  "resourceGroup": "rg-expensemgmt-20260207",
  "location": "uksouth",
  "baseName": "expensemgmt",
  "webAppName": "app-expensemgmt-abc123",
  "sqlServerFqdn": "sql-expensemgmt-abc123.database.windows.net",
  "databaseName": "Northwind",
  "managedIdentityName": "id-expensemgmt-abc123",
  "managedIdentityClientId": "00000000-0000-0000-0000-000000000000",
  "managedIdentityPrincipalId": "00000000-0000-0000-0000-000000000000",
  "appInsightsConnectionString": "InstrumentationKey=...",
  "deployGenAI": true,
  "openAIEndpoint": "https://oai-expensemgmt-abc123.openai.azure.com/",
  "openAIModelName": "gpt-4o",
  "deploymentTimestamp": "2026-02-07T10:30:00Z"
}
```

## Related Documentation

- [Infrastructure Deployment](../deploy-infra/README.md)
- [Unified Deployment](../deploy-all.ps1)
- [CI/CD Setup](../.github/CICD-SETUP.md)
- [Application Architecture](../src/ExpenseManagement/README.md)

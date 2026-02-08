<#
.SYNOPSIS
    Deploys the Expense Management infrastructure to Azure.

.DESCRIPTION
    This script automates the complete infrastructure deployment including:
    - Azure resources via Bicep (App Service, SQL Database, Managed Identity, Monitoring)
    - Database schema and stored procedures via sqlcmd
    - Managed Identity database user creation (SID-based)
    - App Service configuration (connection strings, App Insights, GenAI settings)
    - Deployment context file for application deployment

    Supports both local interactive and CI/CD execution with automatic detection.

.PARAMETER ResourceGroup
    Name of the Azure resource group (required). Use fresh names with timestamps.

.PARAMETER Location
    Azure region for deployment (required). Example: 'uksouth', 'eastus'

.PARAMETER BaseName
    Base name for resource naming (optional). Defaults to 'expensemgmt'.

.PARAMETER DeployGenAI
    Switch to deploy GenAI resources (Azure OpenAI, AI Search).

.PARAMETER SkipDatabase
    Skip database schema and stored procedures import (for redeployments).

.EXAMPLE
    .\deploy.ps1 -ResourceGroup "rg-expensemgmt-20260207" -Location "uksouth"
    
.EXAMPLE
    .\deploy.ps1 -ResourceGroup "rg-expensemgmt-20260207" -Location "uksouth" -DeployGenAI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$false)]
    [string]$BaseName = "expensemgmt",
    
    [Parameter(Mandatory=$false)]
    [switch]$DeployGenAI,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDatabase
)

$ErrorActionPreference = "Stop"

# Display header
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Infrastructure Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host "Location:       $Location" -ForegroundColor Yellow
Write-Host "Base Name:      $BaseName" -ForegroundColor Yellow
Write-Host "Deploy GenAI:   $DeployGenAI" -ForegroundColor Yellow
Write-Host ""

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "You are using PowerShell $($PSVersionTable.PSVersion). PowerShell 7+ is recommended for better compatibility."
    Write-Host "Download: https://aka.ms/powershell-release" -ForegroundColor Gray
    Write-Host ""
}

# Detect CI/CD environment
$IsCI = $env:GITHUB_ACTIONS -eq "true" -or $env:TF_BUILD -eq "true" -or $env:CI -eq "true"
Write-Host "Execution Mode: $(if ($IsCI) { 'CI/CD (GitHub Actions)' } else { 'Local Interactive' })" -ForegroundColor Cyan
Write-Host ""

# Validate Azure CLI is installed
Write-Host "Validating prerequisites..." -ForegroundColor Yellow
$azVersion = az version --output json 2>$null | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $null -eq $azVersion) {
    Write-Error "Azure CLI is not installed. Install from https://aka.ms/azure-cli"
    exit 1
}
Write-Host "✓ Azure CLI version $($azVersion.'azure-cli')" -ForegroundColor Green

# Validate user is logged in
$account = az account show --output json 2>$null | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $null -eq $account) {
    Write-Error "Azure CLI is not logged in. Run 'az login' first."
    exit 1
}
Write-Host "✓ Logged in to Azure" -ForegroundColor Green
Write-Host "  Subscription: $($account.name)" -ForegroundColor Gray
Write-Host ""

# Get administrator credentials based on execution mode
Write-Host "Retrieving administrator credentials..." -ForegroundColor Yellow

if ($IsCI) {
    # CI/CD Mode - Use Service Principal from environment variable
    $servicePrincipalClientId = $env:AZURE_CLIENT_ID
    
    if ([string]::IsNullOrWhiteSpace($servicePrincipalClientId)) {
        Write-Error "CI/CD mode detected but AZURE_CLIENT_ID environment variable is not set."
        exit 1
    }
    
    # Get Service Principal details
    $spDetails = az ad sp show --id $servicePrincipalClientId --output json 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $null -eq $spDetails) {
        Write-Error "Failed to retrieve Service Principal details for client ID: $servicePrincipalClientId"
        exit 1
    }
    
    $adminObjectId = $spDetails.id
    $adminLogin = $spDetails.displayName
    $adminPrincipalType = "Application"
    $authMethod = "ActiveDirectoryAzCli"
    
    Write-Host "✓ Service Principal: $adminLogin" -ForegroundColor Green
    Write-Host "  Client ID:  $servicePrincipalClientId" -ForegroundColor Gray
    Write-Host "  Object ID:  $adminObjectId" -ForegroundColor Gray
} else {
    # Local Mode - Use signed-in user
    $userDetails = az ad signed-in-user show --output json 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $null -eq $userDetails) {
        Write-Error "Failed to retrieve signed-in user details. Ensure you are logged in with 'az login'."
        exit 1
    }
    
    $adminObjectId = $userDetails.id
    $adminLogin = $userDetails.userPrincipalName
    $adminPrincipalType = "User"
    $authMethod = "ActiveDirectoryDefault"
    
    Write-Host "✓ User: $adminLogin" -ForegroundColor Green
    Write-Host "  Object ID: $adminObjectId" -ForegroundColor Gray
}
Write-Host ""

# Get script directory paths
$scriptDir = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptDir
$bicepTemplate = Join-Path $scriptDir "main.bicep"
$schemaFile = Join-Path $repoRoot "Database-Schema/database_schema.sql"
$storedProcFile = Join-Path $repoRoot "stored-procedures.sql"

# Validate Bicep template exists
if (-not (Test-Path $bicepTemplate)) {
    Write-Error "Bicep template not found: $bicepTemplate"
    exit 1
}

# Validate database files exist
if (-not $SkipDatabase) {
    if (-not (Test-Path $schemaFile)) {
        Write-Error "Database schema file not found: $schemaFile"
        exit 1
    }
    if (-not (Test-Path $storedProcFile)) {
        Write-Error "Stored procedures file not found: $storedProcFile"
        exit 1
    }
}

Write-Host "✓ Template and database files validated" -ForegroundColor Green
Write-Host ""

# Create resource group
Write-Host "Creating resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create resource group: $ResourceGroup"
    exit 1
}
Write-Host "✓ Resource group created: $ResourceGroup" -ForegroundColor Green
Write-Host ""

# Deploy Bicep template
Write-Host "Deploying infrastructure..." -ForegroundColor Yellow
Write-Host "(This may take 5-10 minutes...)" -ForegroundColor Gray
Write-Host ""

$deployOutput = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file $bicepTemplate `
    --parameters location=$Location baseName=$BaseName adminObjectId=$adminObjectId adminLogin=$adminLogin adminPrincipalType=$adminPrincipalType deployGenAI=$($DeployGenAI.ToString().ToLower()) `
    --output json 2>$null

# Handle Azure Policy timing issues
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($deployOutput)) {
    Write-Warning "Deployment command returned an error. This can happen when Azure policies are being applied."
    Write-Host "Waiting for policy deployments to settle..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15
    
    # Find the main Bicep deployment (not policy-related)
    $allDeployments = az deployment group list --resource-group $ResourceGroup --output json 2>$null | ConvertFrom-Json
    $mainDeployment = $allDeployments | Where-Object { 
        $_.name -notlike "PolicyDeployment_*" -and 
        $_.name -notlike "Failure-Anomalies-*" -and
        $_.name -notlike "*-diagnostics-*" -and
        $_.properties.provisioningState -eq "Succeeded"
    } | Sort-Object -Property @{Expression={[datetime]$_.properties.timestamp}; Descending=$true} | Select-Object -First 1
    
    if ($mainDeployment) {
        Write-Host "✓ Found successful deployment: $($mainDeployment.name)" -ForegroundColor Green
        $deployOutput = az deployment group show --resource-group $ResourceGroup --name $mainDeployment.name --output json 2>$null
    } else {
        Write-Error "Infrastructure deployment failed. Check Azure portal for details."
        exit 1
    }
}

# Parse deployment outputs
$deployment = $deployOutput | ConvertFrom-Json
$outputs = $deployment.properties.outputs

# Extract output values
$webAppName = $outputs.webAppName.value
$sqlServerFqdn = $outputs.sqlServerFqdn.value
$databaseName = $outputs.databaseName.value
$managedIdentityName = $outputs.managedIdentityName.value
$managedIdentityClientId = $outputs.managedIdentityClientId.value
$managedIdentityPrincipalId = $outputs.managedIdentityPrincipalId.value
$appInsightsConnectionString = $outputs.appInsightsConnectionString.value
$openAIEndpoint = if ($DeployGenAI) { $outputs.openAIEndpoint.value } else { "" }
$openAIModelName = if ($DeployGenAI) { $outputs.openAIModelName.value } else { "" }

Write-Host ""
Write-Host "✓ Infrastructure deployment completed" -ForegroundColor Green
Write-Host "  Web App:           $webAppName" -ForegroundColor Gray
Write-Host "  SQL Server:        $sqlServerFqdn" -ForegroundColor Gray
Write-Host "  Database:          $databaseName" -ForegroundColor Gray
Write-Host "  Managed Identity:  $managedIdentityName" -ForegroundColor Gray
if ($DeployGenAI) {
    Write-Host "  OpenAI Endpoint:   $openAIEndpoint" -ForegroundColor Gray
    Write-Host "  OpenAI Model:      $openAIModelName" -ForegroundColor Gray
}
Write-Host ""

# Skip database operations if requested
if ($SkipDatabase) {
    Write-Host "Skipping database operations (as requested)" -ForegroundColor Yellow
    Write-Host ""
} else {
    # Wait for SQL Server to be ready
    Write-Host "Waiting for SQL Server to become ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    Write-Host "✓ SQL Server ready" -ForegroundColor Green
    Write-Host ""

    # Add firewall rule for current IP (local mode only)
    if (-not $IsCI) {
        Write-Host "Adding firewall rule for current IP..." -ForegroundColor Yellow
        $currentIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()
        Write-Host "  Current IP: $currentIp" -ForegroundColor Gray
        
        $sqlServerName = $sqlServerFqdn -replace '\.database\.windows\.net$', ''
        az sql server firewall-rule create `
            --resource-group $ResourceGroup `
            --server $sqlServerName `
            --name "AllowCurrentIP" `
            --start-ip-address $currentIp `
            --end-ip-address $currentIp `
            --output none 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Firewall rule added" -ForegroundColor Green
        } else {
            Write-Warning "Failed to add firewall rule. You may need to add it manually."
        }
        Write-Host ""
    }

    # Import database schema
    Write-Host "Importing database schema..." -ForegroundColor Yellow
    Write-Host "  Using authentication: $authMethod" -ForegroundColor Gray
    
    sqlcmd -S $sqlServerFqdn -d $databaseName "--authentication-method=$authMethod" -i $schemaFile -b
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to import database schema. Check sqlcmd output above."
        exit 1
    }
    Write-Host "✓ Database schema imported" -ForegroundColor Green
    Write-Host ""

    # Create managed identity database user (SID-based)
    Write-Host "Creating database user for managed identity..." -ForegroundColor Yellow
    
    # Convert Client ID (GUID) to SID hex format
    $guidBytes = [System.Guid]::Parse($managedIdentityClientId).ToByteArray()
    $sidHex = "0x" + [System.BitConverter]::ToString($guidBytes).Replace("-", "")
    
    $createUserSql = @"
-- Drop user if exists (for idempotency)
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = '$managedIdentityName')
    DROP USER [$managedIdentityName];

-- Create user with SID (no Directory Reader required)
CREATE USER [$managedIdentityName] WITH SID = $sidHex, TYPE = E;

-- Grant permissions
ALTER ROLE db_datareader ADD MEMBER [$managedIdentityName];
ALTER ROLE db_datawriter ADD MEMBER [$managedIdentityName];
GRANT EXECUTE TO [$managedIdentityName];
"@
    
    # Write SQL to temp file and execute (avoid piping which causes go-sqlcmd crashes)
    $tempFile = [System.IO.Path]::GetTempFileName() + ".sql"
    $createUserSql | Out-File -FilePath $tempFile -Encoding UTF8
    
    sqlcmd -S $sqlServerFqdn -d $databaseName "--authentication-method=$authMethod" -i $tempFile -b
    
    $sqlcmdExitCode = $LASTEXITCODE
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    
    if ($sqlcmdExitCode -ne 0) {
        Write-Error "Failed to create database user for managed identity."
        exit 1
    }
    Write-Host "✓ Database user created: $managedIdentityName" -ForegroundColor Green
    Write-Host ""

    # Import stored procedures
    Write-Host "Importing stored procedures..." -ForegroundColor Yellow
    
    sqlcmd -S $sqlServerFqdn -d $databaseName "--authentication-method=$authMethod" -i $storedProcFile -b
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to import stored procedures. Check sqlcmd output above."
        exit 1
    }
    Write-Host "✓ Stored procedures imported" -ForegroundColor Green
    Write-Host ""
}

# Configure App Service settings
Write-Host "Configuring App Service settings..." -ForegroundColor Yellow

# Build SQL connection string with Managed Identity authentication
$connectionString = "Server=tcp:$sqlServerFqdn,1433;Initial Catalog=$databaseName;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Managed Identity;User Id=$managedIdentityClientId;"

# Set AZURE_CLIENT_ID (required for DefaultAzureCredential)
az webapp config appsettings set `
    --resource-group $ResourceGroup `
    --name $webAppName `
    --settings AZURE_CLIENT_ID=$managedIdentityClientId `
    --output none 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set AZURE_CLIENT_ID app setting."
    exit 1
}

# Set connection string
az webapp config connection-string set `
    --resource-group $ResourceGroup `
    --name $webAppName `
    --connection-string-type SQLAzure `
    --settings DefaultConnection=$connectionString `
    --output none 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set connection string."
    exit 1
}

# Set Application Insights connection string
az webapp config appsettings set `
    --resource-group $ResourceGroup `
    --name $webAppName `
    --settings APPLICATIONINSIGHTS_CONNECTION_STRING=$appInsightsConnectionString `
    --output none 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set Application Insights connection string."
    exit 1
}

Write-Host "✓ Core App Service settings configured" -ForegroundColor Green

# Configure GenAI settings if deployed
if ($DeployGenAI) {
    Write-Host "Configuring GenAI settings..." -ForegroundColor Yellow
    
    az webapp config appsettings set `
        --resource-group $ResourceGroup `
        --name $webAppName `
        --settings `
            GenAISettings__OpenAIEndpoint=$openAIEndpoint `
            GenAISettings__OpenAIModelName=$openAIModelName `
            ManagedIdentityClientId=$managedIdentityClientId `
        --output none 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to set GenAI app settings."
        exit 1
    }
    
    Write-Host "✓ GenAI settings configured" -ForegroundColor Green
}
Write-Host ""

# Save deployment context file
Write-Host "Saving deployment context..." -ForegroundColor Yellow

$deploymentContext = @{
    resourceGroup = $ResourceGroup
    location = $Location
    baseName = $BaseName
    webAppName = $webAppName
    sqlServerFqdn = $sqlServerFqdn
    databaseName = $databaseName
    managedIdentityName = $managedIdentityName
    managedIdentityClientId = $managedIdentityClientId
    managedIdentityPrincipalId = $managedIdentityPrincipalId
    appInsightsConnectionString = $appInsightsConnectionString
    deployGenAI = $DeployGenAI.IsPresent
    openAIEndpoint = $openAIEndpoint
    openAIModelName = $openAIModelName
    deploymentTimestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
}

$contextFile = Join-Path $repoRoot ".deployment-context.json"
$deploymentContext | ConvertTo-Json -Depth 10 | Out-File -FilePath $contextFile -Encoding UTF8

Write-Host "✓ Deployment context saved: $contextFile" -ForegroundColor Green
Write-Host ""

# Display summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Infrastructure Deployment Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resources deployed:" -ForegroundColor Yellow
Write-Host "  • App Service:        $webAppName" -ForegroundColor Gray
Write-Host "  • SQL Server:         $sqlServerFqdn" -ForegroundColor Gray
Write-Host "  • Database:           $databaseName" -ForegroundColor Gray
Write-Host "  • Managed Identity:   $managedIdentityName" -ForegroundColor Gray
if ($DeployGenAI) {
    Write-Host "  • Azure OpenAI:       $openAIEndpoint" -ForegroundColor Gray
    Write-Host "  • OpenAI Model:       $openAIModelName" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Next step:" -ForegroundColor Yellow
Write-Host "  Deploy application code with: .\deploy-app\deploy.ps1" -ForegroundColor Gray
Write-Host ""

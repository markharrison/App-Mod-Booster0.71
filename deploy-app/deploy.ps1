<#
.SYNOPSIS
    Deploys the Expense Management application to Azure App Service.

.DESCRIPTION
    This script automates the application deployment by:
    - Reading deployment context from .deployment-context.json
    - Building and publishing the .NET 8 application
    - Creating a deployment zip package
    - Deploying to Azure App Service with clean and restart flags
    - Displaying application URLs

    Works seamlessly with deploy-infra/deploy.ps1 via the deployment context file.

.PARAMETER ResourceGroup
    Azure resource group name (optional - overrides context file).

.PARAMETER WebAppName
    Azure App Service name (optional - overrides context file).

.PARAMETER SkipBuild
    Skip the dotnet build/publish step (for redeployments).

.EXAMPLE
    .\deploy.ps1
    
    Reads from .deployment-context.json and deploys automatically.

.EXAMPLE
    .\deploy.ps1 -ResourceGroup "rg-expensemgmt-20260207" -WebAppName "app-expensemgmt-abc123"
    
    Explicitly specify resource group and web app name.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [string]$WebAppName,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

# Display header
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Application Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get script directory and paths
$scriptDir = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptDir

# Look for deployment context file in current directory or parent directory
$contextFile = $null
$contextFileCurrent = Join-Path $scriptDir ".deployment-context.json"
$contextFileParent = Join-Path $repoRoot ".deployment-context.json"

if (Test-Path $contextFileCurrent) {
    $contextFile = $contextFileCurrent
    Write-Host "✓ Found deployment context: $contextFileCurrent" -ForegroundColor Green
} elseif (Test-Path $contextFileParent) {
    $contextFile = $contextFileParent
    Write-Host "✓ Found deployment context: $contextFileParent" -ForegroundColor Green
} else {
    if ([string]::IsNullOrWhiteSpace($ResourceGroup) -or [string]::IsNullOrWhiteSpace($WebAppName)) {
        Write-Error "No deployment context file found and required parameters not provided."
        Write-Host ""
        Write-Host "Either:" -ForegroundColor Yellow
        Write-Host "  1. Run deploy-infra/deploy.ps1 first to create .deployment-context.json" -ForegroundColor Gray
        Write-Host "  2. Provide -ResourceGroup and -WebAppName parameters explicitly" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
}

# Read deployment context if available
$deployContext = $null
if ($null -ne $contextFile) {
    $deployContext = Get-Content $contextFile | ConvertFrom-Json
    
    # Use context values if parameters not explicitly provided
    if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
        $ResourceGroup = $deployContext.resourceGroup
    }
    if ([string]::IsNullOrWhiteSpace($WebAppName)) {
        $WebAppName = $deployContext.webAppName
    }
}

Write-Host ""
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
Write-Host "Web App Name:   $WebAppName" -ForegroundColor Yellow
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
Write-Host ""

# Build paths relative to script location
$projectPath = Join-Path $repoRoot "src/ExpenseManagement/ExpenseManagement.csproj"
$publishDir = Join-Path $repoRoot "src/ExpenseManagement/bin/Release/net8.0/publish"
$zipFile = Join-Path $repoRoot "deploy-app/app-deployment.zip"

# Validate project exists
if (-not (Test-Path $projectPath)) {
    Write-Error "Project file not found: $projectPath"
    exit 1
}
Write-Host "✓ Project file validated: ExpenseManagement.csproj" -ForegroundColor Green
Write-Host ""

# Build and publish application
if ($SkipBuild) {
    Write-Host "Skipping build (as requested)" -ForegroundColor Yellow
    Write-Host ""
    
    if (-not (Test-Path $publishDir)) {
        Write-Error "Publish directory not found: $publishDir. Cannot skip build - no previous build exists."
        exit 1
    }
} else {
    Write-Host "Building and publishing application..." -ForegroundColor Yellow
    Write-Host "(This may take 1-2 minutes...)" -ForegroundColor Gray
    Write-Host ""
    
    # Clean previous publish output
    if (Test-Path $publishDir) {
        Remove-Item -Path $publishDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Restore dependencies
    Write-Host "  Restoring dependencies..." -ForegroundColor Gray
    dotnet restore $projectPath --verbosity quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Error "dotnet restore failed. Check output above."
        exit 1
    }
    
    # Build in Release configuration
    Write-Host "  Building in Release mode..." -ForegroundColor Gray
    dotnet build $projectPath --configuration Release --no-restore --verbosity quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Error "dotnet build failed. Check output above."
        exit 1
    }
    
    # Publish application
    Write-Host "  Publishing application..." -ForegroundColor Gray
    dotnet publish $projectPath --configuration Release --no-build --output $publishDir --verbosity quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Error "dotnet publish failed. Check output above."
        exit 1
    }
    
    Write-Host ""
    Write-Host "✓ Application built and published" -ForegroundColor Green
    Write-Host ""
}

# Create deployment zip package
Write-Host "Creating deployment package..." -ForegroundColor Yellow

# Remove old zip if exists
if (Test-Path $zipFile) {
    Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
}

# Create zip with DLL files at root level (required by Azure App Service)
# Azure expects: app.zip/ExpenseManagement.dll (not app.zip/publish/ExpenseManagement.dll)
Compress-Archive -Path "$publishDir/*" -DestinationPath $zipFile -CompressionLevel Optimal

if (-not (Test-Path $zipFile)) {
    Write-Error "Failed to create deployment zip file."
    exit 1
}

$zipSize = (Get-Item $zipFile).Length / 1MB
Write-Host "✓ Deployment package created: $([math]::Round($zipSize, 2)) MB" -ForegroundColor Green
Write-Host ""

# Deploy to Azure App Service
Write-Host "Deploying to Azure App Service..." -ForegroundColor Yellow
Write-Host "(This may take 2-3 minutes...)" -ForegroundColor Gray
Write-Host ""

# Deploy with clean and restart flags
# Note: az webapp deploy outputs progress warnings to stderr which are NORMAL
$deployResult = az webapp deploy `
    --resource-group $ResourceGroup `
    --name $WebAppName `
    --src-path $zipFile `
    --type zip `
    --clean true `
    --restart true `
    --output json 2>&1

# Check if deployment succeeded by parsing the result
# az webapp deploy outputs warnings to stderr but still succeeds
$deploySucceeded = $false

if ($deployResult -match '"status":\s*"RuntimeSuccessful"' -or $deployResult -match 'Deployment has completed successfully') {
    $deploySucceeded = $true
} elseif ($LASTEXITCODE -eq 0) {
    $deploySucceeded = $true
} elseif ($deployResult -match 'completed successfully' -or $deployResult -match 'RuntimeSuccessful') {
    # Even if exit code is non-zero, check if deployment actually succeeded
    $deploySucceeded = $true
}

if ($deploySucceeded) {
    Write-Host ""
    Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Error "Deployment failed. Check Azure portal for details."
    Write-Host "  Portal URL: https://portal.azure.com/#resource/subscriptions/$($account.id)/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$WebAppName" -ForegroundColor Gray
    exit 1
}

# Clean up temporary files
Write-Host ""
Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
Remove-Item -Path $zipFile -Force -ErrorAction SilentlyContinue
Write-Host "✓ Cleanup complete" -ForegroundColor Green
Write-Host ""

# Display application URLs
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Application Deployment Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Application URLs:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Main Application:" -ForegroundColor Green
Write-Host "    https://$WebAppName.azurewebsites.net/Index" -ForegroundColor Cyan
Write-Host ""
Write-Host "  API Documentation:" -ForegroundColor Green
Write-Host "    https://$WebAppName.azurewebsites.net/swagger" -ForegroundColor Cyan
Write-Host ""

# Show Chat URL if GenAI was deployed
if ($null -ne $deployContext -and $deployContext.deployGenAI) {
    Write-Host "  AI Chat Interface:" -ForegroundColor Green
    Write-Host "    https://$WebAppName.azurewebsites.net/Chat" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "Note: The application may take 30-60 seconds to warm up on first request." -ForegroundColor Gray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  • Test the application by visiting the URLs above" -ForegroundColor Gray
Write-Host "  • Check Application Insights for telemetry and logs" -ForegroundColor Gray
Write-Host "  • Monitor App Service metrics in Azure Portal" -ForegroundColor Gray
Write-Host ""

<#
.SYNOPSIS
    Deploys the Expense Management application to Azure App Service.

.DESCRIPTION
    This script automates the deployment of the ASP.NET application including:
    - Building the .NET application
    - Creating a deployment package
    - Deploying to Azure App Service
    
    The script reads configuration from .deployment-context.json created by the
    infrastructure deployment script.

.PARAMETER ResourceGroup
    Optional. The name of the Azure resource group. Overrides context file.

.PARAMETER WebAppName
    Optional. The name of the Azure Web App. Overrides context file.

.PARAMETER SkipBuild
    Switch to skip the build step (useful for redeployments).

.PARAMETER ConfigureSettings
    Switch to configure app settings after deployment.

.EXAMPLE
    .\deploy.ps1

.EXAMPLE
    .\deploy.ps1 -SkipBuild -ConfigureSettings
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$WebAppName,

    [Parameter(Mandatory = $false)]
    [switch]$SkipBuild,

    [Parameter(Mandatory = $false)]
    [switch]$ConfigureSettings
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Expense Management Application Deploy     " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = $PSScriptRoot
$repoRoot = Split-Path -Parent $scriptDir

# Look for deployment context file
$contextFile = $null
$possiblePaths = @(
    (Join-Path $repoRoot ".deployment-context.json"),
    (Join-Path $scriptDir ".deployment-context.json"),
    "./.deployment-context.json",
    "../.deployment-context.json"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $contextFile = $path
        break
    }
}

$context = $null
if ($contextFile) {
    Write-Host "Found deployment context: $contextFile" -ForegroundColor Green
    $context = Get-Content $contextFile | ConvertFrom-Json
}

# Resolve parameters
if (-not $ResourceGroup) {
    if ($context) {
        $ResourceGroup = $context.resourceGroup
    } else {
        Write-Host "Error: ResourceGroup not specified and no context file found." -ForegroundColor Red
        Write-Host "Run deploy-infra/deploy.ps1 first, or specify -ResourceGroup parameter." -ForegroundColor Yellow
        exit 1
    }
}

if (-not $WebAppName) {
    if ($context) {
        $WebAppName = $context.webAppName
    } else {
        Write-Host "Error: WebAppName not specified and no context file found." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "Web App: $WebAppName" -ForegroundColor Gray

# Check Azure CLI
Write-Host ""
Write-Host "Checking Azure CLI..." -ForegroundColor Gray
try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    Write-Host "Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Host "Error: Azure CLI is not installed or not in PATH." -ForegroundColor Red
    exit 1
}

# Build the application
$projectPath = Join-Path $repoRoot "src/ExpenseManagement/ExpenseManagement.csproj"
$publishPath = Join-Path $repoRoot "publish"

if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "Building application..." -ForegroundColor Cyan
    
    if (-not (Test-Path $projectPath)) {
        Write-Host "Error: Project file not found at $projectPath" -ForegroundColor Red
        exit 1
    }
    
    # Clean publish directory
    if (Test-Path $publishPath) {
        Remove-Item -Path $publishPath -Recurse -Force
    }
    
    dotnet publish $projectPath -c Release -o $publishPath
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Build failed." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Build completed successfully." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Skipping build (using existing publish folder)..." -ForegroundColor Yellow
}

# Create deployment zip
Write-Host ""
Write-Host "Creating deployment package..." -ForegroundColor Gray

$zipPath = Join-Path $repoRoot "deploy.zip"

if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}

# Create zip with files at root level
Push-Location $publishPath
Compress-Archive -Path "./*" -DestinationPath $zipPath -Force
Pop-Location

Write-Host "Deployment package created: $zipPath" -ForegroundColor Green

# Deploy to Azure
Write-Host ""
Write-Host "Deploying to Azure App Service..." -ForegroundColor Cyan

az webapp deploy `
    --resource-group $ResourceGroup `
    --name $WebAppName `
    --src-path $zipPath `
    --type zip `
    --clean true `
    --restart true `
    --output none 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Deployment failed." -ForegroundColor Red
    exit 1
}

Write-Host "Deployment completed successfully!" -ForegroundColor Green

# Configure settings if requested
if ($ConfigureSettings -and $context) {
    Write-Host ""
    Write-Host "Configuring app settings..." -ForegroundColor Gray
    
    $connectionString = "Server=tcp:$($context.sqlServerFqdn),1433;Initial Catalog=$($context.databaseName);Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Managed Identity;User Id=$($context.managedIdentityClientId);"
    
    az webapp config connection-string set `
        --resource-group $ResourceGroup `
        --name $WebAppName `
        --connection-string-type SQLAzure `
        --settings DefaultConnection=$connectionString `
        --output none 2>$null
    
    Write-Host "App settings configured." -ForegroundColor Green
}

# Cleanup
Write-Host ""
Write-Host "Cleaning up..." -ForegroundColor Gray
Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
if (-not $SkipBuild) {
    Remove-Item -Path $publishPath -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "Cleanup complete." -ForegroundColor Green

# Get web app URL
$webAppUrl = $null
if ($context -and $context.webAppUrl) {
    $webAppUrl = $context.webAppUrl
} else {
    $webApp = az webapp show --resource-group $ResourceGroup --name $WebAppName --output json 2>$null | ConvertFrom-Json
    $webAppUrl = "https://$($webApp.defaultHostName)"
}

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!                      " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Application URL: $webAppUrl/Index" -ForegroundColor Green
Write-Host "Swagger UI:      $webAppUrl/swagger" -ForegroundColor Green
Write-Host ""

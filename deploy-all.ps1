<#
.SYNOPSIS
    Unified deployment script for the Expense Management application.
    Deploys both infrastructure and application with a single command.

.DESCRIPTION
    This script orchestrates the complete deployment process by calling the
    infrastructure deployment script followed by the application deployment script.
    
    For independent deployments, use the individual scripts:
    - deploy-infra/deploy.ps1 for infrastructure only
    - deploy-app/deploy.ps1 for application only

.PARAMETER ResourceGroup
    Required. The name of the Azure resource group.
    Use unique names with dates (e.g., "rg-expensemgmt-20251206").

.PARAMETER Location
    Required. The Azure region (e.g., 'uksouth', 'eastus', 'westeurope').

.PARAMETER BaseName
    Optional. Base name for resources. Defaults to 'expensemgmt'.

.PARAMETER DeployGenAI
    Optional switch. Include Azure OpenAI and AI Search resources.

.EXAMPLE
    .\deploy-all.ps1 -ResourceGroup "rg-expensemgmt-20251206" -Location "uksouth"

.EXAMPLE
    .\deploy-all.ps1 -ResourceGroup "rg-expensemgmt-20251206" -Location "uksouth" -DeployGenAI
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $false)]
    [string]$BaseName = "expensemgmt",
    
    [switch]$DeployGenAI
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Expense Management - Full Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will deploy both infrastructure and application." -ForegroundColor White
Write-Host ""

# Verify deployment scripts exist
$infraScript = Join-Path $PSScriptRoot "deploy-infra" "deploy.ps1"
$appScript = Join-Path $PSScriptRoot "deploy-app" "deploy.ps1"

if (-not (Test-Path $infraScript)) {
    Write-Error "Infrastructure deployment script not found: $infraScript"
    exit 1
}

if (-not (Test-Path $appScript)) {
    Write-Error "Application deployment script not found: $appScript"
    exit 1
}

Write-Host "✓ Deployment scripts found" -ForegroundColor Green
Write-Host ""

# Phase 1: Infrastructure Deployment
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Phase 1: Infrastructure Deployment" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

$infraParams = @{
    ResourceGroup = $ResourceGroup
    Location = $Location
    BaseName = $BaseName
}

if ($DeployGenAI) {
    $infraParams.DeployGenAI = $true
}

try {
    & $infraScript @infraParams
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Error "Infrastructure deployment failed with exit code $LASTEXITCODE"
        Write-Host ""
        Write-Host "To retry infrastructure deployment:" -ForegroundColor Yellow
        Write-Host "  .\deploy-infra\deploy.ps1 -ResourceGroup `"$ResourceGroup`" -Location `"$Location`"" -ForegroundColor White
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Error "Infrastructure deployment failed: $_"
    Write-Host ""
    Write-Host "To retry infrastructure deployment:" -ForegroundColor Yellow
    Write-Host "  .\deploy-infra\deploy.ps1 -ResourceGroup `"$ResourceGroup`" -Location `"$Location`"" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "✓ Infrastructure deployment completed successfully" -ForegroundColor Green
Write-Host ""

# Brief pause to ensure Azure resources are fully ready
Write-Host "Waiting for Azure resources to stabilize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
Write-Host ""

# Phase 2: Application Deployment
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Phase 2: Application Deployment" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

try {
    & $appScript
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Error "Application deployment failed with exit code $LASTEXITCODE"
        Write-Host ""
        Write-Host "Infrastructure was deployed successfully." -ForegroundColor Green
        Write-Host "To retry application deployment only:" -ForegroundColor Yellow
        Write-Host "  .\deploy-app\deploy.ps1" -ForegroundColor White
        exit 1
    }
}
catch {
    Write-Host ""
    Write-Error "Application deployment failed: $_"
    Write-Host ""
    Write-Host "Infrastructure was deployed successfully." -ForegroundColor Green
    Write-Host "To retry application deployment only:" -ForegroundColor Yellow
    Write-Host "  .\deploy-app\deploy.ps1" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Full Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Read deployment context for summary
$contextFile = Join-Path $PSScriptRoot ".deployment-context.json"
if (Test-Path $contextFile) {
    $context = Get-Content $contextFile | ConvertFrom-Json
    
    Write-Host "Deployment Summary:" -ForegroundColor Cyan
    Write-Host "  Resource Group: $($context.resourceGroup)" -ForegroundColor White
    Write-Host "  Web App: $($context.webAppName)" -ForegroundColor White
    Write-Host "  SQL Server: $($context.sqlServerFqdn)" -ForegroundColor White
    Write-Host "  Database: $($context.databaseName)" -ForegroundColor White
    Write-Host "  Managed Identity: $($context.managedIdentityClientId)" -ForegroundColor White
    if ($context.deployedGenAI) {
        Write-Host "  GenAI Resources: Deployed" -ForegroundColor Magenta
    }
    Write-Host ""
    Write-Host "Application URL:" -ForegroundColor Cyan
    Write-Host "  https://$($context.webAppName).azurewebsites.net/Index" -ForegroundColor Green
    Write-Host ""
}

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Open the application URL above" -ForegroundColor White
Write-Host "  2. Test the expense management functionality" -ForegroundColor White
Write-Host "  3. View logs in Azure Portal > Application Insights" -ForegroundColor White
Write-Host ""

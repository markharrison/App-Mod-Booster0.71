<#
.SYNOPSIS
    Unified deployment script that deploys both infrastructure and application.

.DESCRIPTION
    This script orchestrates the complete deployment by calling:
    1. deploy-infra/deploy.ps1 - Infrastructure deployment
    2. deploy-app/deploy.ps1 - Application deployment

.PARAMETER ResourceGroup
    The name of the Azure resource group to deploy to.

.PARAMETER Location
    The Azure region for deployment (e.g., 'uksouth', 'eastus').

.PARAMETER BaseName
    Base name for resources. Defaults to 'expensemgmt'.

.PARAMETER DeployGenAI
    Switch to deploy Azure OpenAI and AI Search resources.

.EXAMPLE
    .\deploy-all.ps1 -ResourceGroup "rg-expensemgmt-20251208" -Location "uksouth"

.EXAMPLE
    .\deploy-all.ps1 -ResourceGroup "rg-expensemgmt-20251208" -Location "uksouth" -DeployGenAI
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(Mandatory = $false)]
    [string]$BaseName = "expensemgmt",

    [Parameter(Mandatory = $false)]
    [switch]$DeployGenAI
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Expense Management Full Deployment        " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = $PSScriptRoot
$infraScript = Join-Path $scriptDir "deploy-infra/deploy.ps1"
$appScript = Join-Path $scriptDir "deploy-app/deploy.ps1"

# Validate scripts exist
if (-not (Test-Path $infraScript)) {
    Write-Host "Error: Infrastructure deployment script not found at $infraScript" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $appScript)) {
    Write-Host "Error: Application deployment script not found at $appScript" -ForegroundColor Red
    exit 1
}

# Deploy infrastructure
Write-Host "Phase 1: Infrastructure Deployment" -ForegroundColor Cyan
Write-Host "-----------------------------------" -ForegroundColor Cyan

$infraArgs = @{
    ResourceGroup = $ResourceGroup
    Location = $Location
    BaseName = $BaseName
}

if ($DeployGenAI) {
    $infraArgs["DeployGenAI"] = $true
}

& $infraScript @infraArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Error: Infrastructure deployment failed." -ForegroundColor Red
    Write-Host "To retry, run: .\deploy-infra\deploy.ps1 -ResourceGroup '$ResourceGroup' -Location '$Location'" -ForegroundColor Yellow
    exit 1
}

# Wait for resources to stabilize
Write-Host ""
Write-Host "Waiting for Azure resources to stabilize..." -ForegroundColor Gray
Start-Sleep -Seconds 15

# Deploy application
Write-Host ""
Write-Host "Phase 2: Application Deployment" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Cyan

$appArgs = @{}

& $appScript @appArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Error: Application deployment failed." -ForegroundColor Red
    Write-Host "To retry, run: .\deploy-app\deploy.ps1" -ForegroundColor Yellow
    exit 1
}

# Final summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Full Deployment Complete!                 " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

# Read context for final URL
$contextFile = Join-Path $scriptDir ".deployment-context.json"
if (Test-Path $contextFile) {
    $context = Get-Content $contextFile | ConvertFrom-Json
    Write-Host "Application URL: $($context.webAppUrl)/Index" -ForegroundColor Cyan
    if ($context.deployedGenAI) {
        Write-Host "Chat UI:         $($context.webAppUrl)/Chat" -ForegroundColor Cyan
    }
}
Write-Host ""

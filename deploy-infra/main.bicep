// Main orchestration template for Expense Management application infrastructure
targetScope = 'resourceGroup'

@description('Azure region where resources will be deployed')
param location string = 'uksouth'

@description('Base identifier used across all resource names')
param baseName string = 'expensemgmt'

@description('Deployment timestamp for unique resource naming')
param timestamp string = utcNow('yyyyMMddHHmm')

@description('SQL administrator username')
param sqlAdminLogin string = 'sqladmin'

@description('Azure AD administrator Object ID for SQL Server')
param adminObjectId string

@description('Azure AD administrator login name (UPN or display name)')
param adminLogin string

@description('Type of Azure AD administrator principal')
@allowed(['User', 'Application'])
param adminPrincipalType string = 'User'

@description('Enable GenAI resources (Azure OpenAI + AI Search)')
param deployGenAI bool = false

// Deploy managed identity first - required by other resources
module identityDeployment 'modules/managed-identity.bicep' = {
  name: 'identity-deployment'
  params: {
    baseName: baseName
    location: location
    timestamp: timestamp
  }
}

// Deploy monitoring infrastructure second
module monitoringDeployment 'modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  params: {
    baseName: baseName
    location: location
  }
}

// Deploy App Service third - depends on identity and monitoring
module appServiceDeployment 'modules/app-service.bicep' = {
  name: 'appservice-deployment'
  params: {
    baseName: baseName
    location: location
    appInsightsConnectionString: monitoringDeployment.outputs.appInsightsConnectionString
    managedIdentityId: identityDeployment.outputs.managedIdentityId
  }
}

// Configure App Service diagnostics fourth - depends on App Service and monitoring
module appServiceDiagnosticsDeployment 'modules/app-service-diagnostics.bicep' = {
  name: 'appservice-diagnostics-deployment'
  params: {
    appServiceName: appServiceDeployment.outputs.webAppName
    logAnalyticsWorkspaceId: monitoringDeployment.outputs.logAnalyticsWorkspaceId
  }
}

// Deploy Azure SQL resources
module sqlDeployment 'modules/azure-sql.bicep' = {
  name: 'sql-deployment'
  params: {
    baseName: baseName
    location: location
    sqlAdminLogin: sqlAdminLogin
    adminObjectId: adminObjectId
    adminLogin: adminLogin
    adminPrincipalType: adminPrincipalType
  }
}

// Configure SQL Database diagnostics
module sqlDiagnosticsDeployment 'modules/sql-diagnostics.bicep' = {
  name: 'sql-diagnostics-deployment'
  params: {
    sqlServerName: sqlDeployment.outputs.sqlServerName
    sqlDatabaseName: sqlDeployment.outputs.databaseName
    workspaceResourceId: monitoringDeployment.outputs.logAnalyticsWorkspaceId
  }
}

// Conditionally deploy GenAI resources
module genAIDeployment 'modules/genai.bicep' = if (deployGenAI) {
  name: 'genai-deployment'
  params: {
    baseIdentifier: baseName
    azureRegion: location
    identityPrincipalId: identityDeployment.outputs.principalId
  }
}

// Output all configuration details needed by deployment scripts
output webAppName string = appServiceDeployment.outputs.webAppName
output sqlServerFqdn string = sqlDeployment.outputs.sqlServerFqdn
output databaseName string = sqlDeployment.outputs.databaseName
output managedIdentityName string = identityDeployment.outputs.managedIdentityName
output managedIdentityClientId string = identityDeployment.outputs.clientId
output managedIdentityPrincipalId string = identityDeployment.outputs.principalId
output appInsightsConnectionString string = monitoringDeployment.outputs.appInsightsConnectionString
output logAnalyticsWorkspaceId string = monitoringDeployment.outputs.logAnalyticsWorkspaceId
output openAIEndpoint string = deployGenAI ? genAIDeployment.outputs.?openAIEndpoint ?? '' : ''
output openAIModelName string = deployGenAI ? genAIDeployment.outputs.?openAIModelName ?? '' : ''

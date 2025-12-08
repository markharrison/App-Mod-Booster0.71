@description('Azure region for resources')
param location string

@description('Base name for resources')
param baseName string = 'expensemgmt'

@description('Timestamp for unique naming (used for managed identity)')
param timestamp string = utcNow('yyyyMMddHHmm')

@description('SQL Server administrator Object ID')
param adminObjectId string

@description('SQL Server administrator login name')
param adminLogin string

@description('Principal type for SQL administrator')
@allowed(['User', 'Application'])
param adminPrincipalType string = 'User'

@description('Deploy GenAI resources (Azure OpenAI and AI Search)')
param deployGenAI bool = false

// Deploy Managed Identity first
module managedIdentity 'modules/managed-identity.bicep' = {
  name: 'managedIdentity'
  params: {
    location: location
    baseName: baseName
    timestamp: timestamp
  }
}

// Deploy Monitoring (without App Service diagnostics to avoid circular dependency)
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    baseName: baseName
  }
}

// Deploy App Service
module appService 'modules/app-service.bicep' = {
  name: 'appService'
  params: {
    location: location
    baseName: baseName
    managedIdentityId: managedIdentity.outputs.identityId
    managedIdentityClientId: managedIdentity.outputs.clientId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
  }
}

// Deploy Azure SQL
module azureSql 'modules/azure-sql.bicep' = {
  name: 'azureSql'
  params: {
    location: location
    baseName: baseName
    adminObjectId: adminObjectId
    adminLogin: adminLogin
    adminPrincipalType: adminPrincipalType
  }
}

// Deploy App Service diagnostics after App Service is created
module appServiceDiagnostics 'modules/app-service-diagnostics.bicep' = {
  name: 'appServiceDiagnostics'
  params: {
    appServiceName: appService.outputs.webAppName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Deploy SQL diagnostics after SQL is created
module sqlDiagnostics 'modules/sql-diagnostics.bicep' = {
  name: 'sqlDiagnostics'
  params: {
    sqlServerName: azureSql.outputs.sqlServerName
    databaseName: azureSql.outputs.databaseName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Conditionally deploy GenAI resources
module genAI 'modules/genai.bicep' = if (deployGenAI) {
  name: 'genAI'
  params: {
    baseName: baseName
    managedIdentityPrincipalId: managedIdentity.outputs.principalId
  }
}

// Outputs
@description('The name of the web app')
output webAppName string = appService.outputs.webAppName

@description('The hostname of the web app')
output webAppHostName string = appService.outputs.webAppHostName

@description('The SQL Server FQDN')
output sqlServerFqdn string = azureSql.outputs.sqlServerFqdn

@description('The SQL Server name')
output sqlServerName string = azureSql.outputs.sqlServerName

@description('The database name')
output databaseName string = azureSql.outputs.databaseName

@description('The managed identity client ID')
output managedIdentityClientId string = managedIdentity.outputs.clientId

@description('The managed identity principal ID')
output managedIdentityPrincipalId string = managedIdentity.outputs.principalId

@description('The managed identity name')
output managedIdentityName string = managedIdentity.outputs.identityName

@description('Application Insights connection string')
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString

@description('Azure OpenAI endpoint (empty if not deployed)')
output openAIEndpoint string = deployGenAI ? genAI.outputs.openAIEndpoint : ''

@description('Azure OpenAI model name (empty if not deployed)')
output openAIModelName string = deployGenAI ? genAI.outputs.openAIModelName : ''

@description('Azure AI Search endpoint (empty if not deployed)')
output searchEndpoint string = deployGenAI ? genAI.outputs.searchEndpoint : ''

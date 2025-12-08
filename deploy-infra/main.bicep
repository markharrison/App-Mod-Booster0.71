@description('The Azure region where resources will be deployed')
param location string

@description('The base name for all resources')
param baseName string = 'expensemgmt'

@description('The Object ID of the Azure AD administrator for SQL Server')
param adminObjectId string

@description('The User Principal Name or Display Name of the Azure AD administrator')
param adminUsername string

@description('The principal type of the administrator (User for interactive, Application for CI/CD)')
@allowed(['User', 'Application'])
param adminPrincipalType string = 'User'

@description('Whether to deploy GenAI resources (Azure OpenAI and AI Search)')
param deployGenAI bool = false

@description('Timestamp for unique naming')
param timestamp string = utcNow('yyyyMMddHHmm')

// Deploy managed identity first (needed by all other resources)
module managedIdentity 'modules/managed-identity.bicep' = {
  name: 'managedIdentity'
  params: {
    location: location
    baseName: baseName
    timestamp: timestamp
  }
}

// Deploy monitoring resources (without App Service diagnostics to avoid circular dependency)
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    baseName: baseName
  }
}

// Deploy App Service with managed identity and Application Insights
module appService 'modules/app-service.bicep' = {
  name: 'appService'
  params: {
    location: location
    baseName: baseName
    managedIdentityId: managedIdentity.outputs.managedIdentityId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
  }
}

// Deploy SQL Server and Database
module azureSQL 'modules/azure-sql.bicep' = {
  name: 'azureSQL'
  params: {
    location: location
    baseName: baseName
    adminObjectId: adminObjectId
    adminUsername: adminUsername
    adminPrincipalType: adminPrincipalType
  }
}

// Deploy App Service diagnostics after App Service is created
module appServiceDiagnostics 'modules/app-service-diagnostics.bicep' = {
  name: 'appServiceDiagnostics'
  params: {
    appServiceName: appService.outputs.webAppName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    location: location
  }
}

// Deploy SQL Database diagnostics
module sqlDatabaseDiagnostics 'modules/sql-database-diagnostics.bicep' = {
  name: 'sqlDatabaseDiagnostics'
  params: {
    sqlServerName: azureSQL.outputs.sqlServerName
    sqlDatabaseName: azureSQL.outputs.sqlDatabaseName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

// Conditionally deploy GenAI resources
module genAI 'modules/genai.bicep' = if (deployGenAI) {
  name: 'genAI'
  params: {
    location: 'swedencentral' // Better quota availability for GPT-4o
    baseName: baseName
    managedIdentityPrincipalId: appService.outputs.managedIdentityPrincipalId
  }
}

// Outputs
@description('The name of the resource group')
output resourceGroupName string = resourceGroup().name

@description('The name of the web app')
output webAppName string = appService.outputs.webAppName

@description('The hostname of the web app')
output webAppHostName string = appService.outputs.webAppHostName

@description('The fully qualified domain name of the SQL Server')
output sqlServerFqdn string = azureSQL.outputs.sqlServerFqdn

@description('The name of the SQL Server')
output sqlServerName string = azureSQL.outputs.sqlServerName

@description('The name of the SQL Database')
output sqlDatabaseName string = azureSQL.outputs.sqlDatabaseName

@description('The client ID of the managed identity')
output managedIdentityClientId string = managedIdentity.outputs.managedIdentityClientId

@description('The name of the managed identity')
output managedIdentityName string = managedIdentity.outputs.managedIdentityName

@description('The Application Insights connection string')
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString

@description('The Azure OpenAI endpoint (empty if GenAI not deployed)')
output openAIEndpoint string = deployGenAI ? genAI.outputs.openAIEndpoint : ''

@description('The Azure OpenAI model name (empty if GenAI not deployed)')
output openAIModelName string = deployGenAI ? genAI.outputs.openAIModelName : ''

@description('The Azure AI Search endpoint (empty if GenAI not deployed)')
output searchEndpoint string = deployGenAI ? genAI.outputs.searchEndpoint : ''

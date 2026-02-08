@description('App Service name')
param appServiceName string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

// Reference to existing App Service
resource webApp 'Microsoft.Web/sites@2022-09-01' existing = {
  name: appServiceName
}

// Diagnostic settings for App Service
resource appServiceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'app-service-diagnostics'
  scope: webApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AppServiceAuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Outputs
output diagnosticSettingsName string = appServiceDiagnostics.name

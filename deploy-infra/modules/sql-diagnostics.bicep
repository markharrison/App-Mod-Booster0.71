@description('Name of the SQL Server')
param sqlServerName string

@description('Name of the SQL Database')
param sqlDatabaseName string

@description('Resource ID of the Log Analytics Workspace for diagnostics')
param workspaceResourceId string

// Reference the existing database resource for diagnostic configuration
resource existingDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' existing = {
  name: '${sqlServerName}/${sqlDatabaseName}'
}

// Configure diagnostic collection for the database
resource databaseDiagnosticCollection 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'sql-db-diagnostics'
  scope: existingDatabase
  properties: {
    workspaceId: workspaceResourceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output diagnosticConfigurationName string = databaseDiagnosticCollection.name

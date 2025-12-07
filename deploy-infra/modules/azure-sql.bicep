@description('The location where the SQL Server will be deployed')
param location string

@description('The base name for resources')
param baseName string

@description('The Object ID of the Azure AD administrator')
param adminObjectId string

@description('The User Principal Name or Display Name of the Azure AD administrator')
param adminUsername string

@description('The principal type of the administrator (User or Application)')
@allowed(['User', 'Application'])
param adminPrincipalType string = 'User'

var uniqueSuffix = uniqueString(resourceGroup().id)
var sqlServerName = toLower('sql-${baseName}-${uniqueSuffix}')
var databaseName = 'Northwind'

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      login: adminUsername
      sid: adminObjectId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: true
      principalType: adminPrincipalType
    }
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: databaseName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2GB
  }
}

resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

@description('The fully qualified domain name of the SQL Server')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('The name of the SQL Server')
output sqlServerName string = sqlServer.name

@description('The name of the SQL Database')
output sqlDatabaseName string = sqlDatabase.name

@description('The resource ID of the SQL Database')
output sqlDatabaseId string = sqlDatabase.id

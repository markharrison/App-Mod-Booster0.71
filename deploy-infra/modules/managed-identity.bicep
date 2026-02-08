@description('Base name for the managed identity')
param baseName string

@description('Location for the managed identity')
param location string

@description('Timestamp for unique naming')
param timestamp string

// Generate unique name with lowercase
var uniqueSuffix = uniqueString(resourceGroup().id)
var managedIdentityName = toLower('mid-${baseName}-${uniqueSuffix}-${timestamp}')

// User-assigned managed identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

// Outputs
output managedIdentityName string = managedIdentity.name
output managedIdentityId string = managedIdentity.id
output principalId string = managedIdentity.properties.principalId
output clientId string = managedIdentity.properties.clientId

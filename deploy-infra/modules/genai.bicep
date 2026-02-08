@description('Base identifier for GenAI resources')
param baseIdentifier string

@description('Azure region for GenAI deployment')
param azureRegion string

@description('Principal ID of the managed identity for role assignments')
param identityPrincipalId string

// Sweden Central for Azure OpenAI (better quota availability)
var openAIRegion = 'swedencentral'
var modelDeploymentName = 'gpt-4o'
var modelVersion = '2024-05-13'

// Generate lowercase unique identifiers
var resourceSuffix = uniqueString(resourceGroup().id)
var openAIAccountName = toLower('${baseIdentifier}-oai-${resourceSuffix}')
var searchServiceName = toLower('${baseIdentifier}-search-${resourceSuffix}')

// Azure OpenAI Account
resource openAIAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: openAIAccountName
  location: openAIRegion
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: openAIAccountName
    publicNetworkAccess: 'Enabled'
  }
}

// Deploy GPT-4o model
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openAIAccount
  name: modelDeploymentName
  sku: {
    name: 'Standard'
    capacity: 8
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelDeploymentName
      version: modelVersion
    }
  }
}

// Azure AI Search service
resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: azureRegion
  sku: {
    name: 'basic'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'enabled'
  }
}

// Role assignment: Cognitive Services OpenAI User
var cognitiveServicesUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
resource openAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAIAccount.id, identityPrincipalId, cognitiveServicesUserRoleId)
  scope: openAIAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUserRoleId)
    principalId: identityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Search Index Data Contributor
var searchIndexDataContributorRoleId = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
resource searchContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, identityPrincipalId, searchIndexDataContributorRoleId)
  scope: searchService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalId: identityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Export GenAI configuration details
output openAIEndpoint string = openAIAccount.properties.endpoint
output openAIModelName string = modelDeploymentName
output searchServiceEndpoint string = 'https://${searchService.name}.search.windows.net'
output searchServiceName string = searchService.name

@description('Location for the GenAI resources (should be a region with GPT-4o availability like Sweden Central)')
param location string = 'swedencentral'

@description('Base name for resources')
param baseName string

@description('Principal ID of the managed identity for role assignments')
param managedIdentityPrincipalId string

var uniqueSuffix = uniqueString(resourceGroup().id)
var openAIName = toLower('oai-${baseName}-${uniqueSuffix}')
var searchServiceName = toLower('srch-${baseName}-${uniqueSuffix}')
var modelName = 'gpt-4o'
var modelDeploymentName = 'gpt-4o'

resource openAI 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: openAIName
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: openAIName
    publicNetworkAccess: 'Enabled'
  }
}

resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-10-01-preview' = {
  parent: openAI
  name: modelDeploymentName
  sku: {
    name: 'Standard'
    capacity: 8
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: '2024-08-06'
    }
  }
}

resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: location
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

// Role assignment for Cognitive Services OpenAI User
var cognitiveServicesOpenAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource openAIRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAI.id, managedIdentityPrincipalId, cognitiveServicesOpenAIUserRoleId)
  scope: openAI
  properties: {
    principalId: managedIdentityPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

// Role assignment for Search Index Data Contributor
var searchIndexDataContributorRoleId = '8ebe5a00-799e-43f5-93ac-243d3dce84a7'

resource searchRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(searchService.id, managedIdentityPrincipalId, searchIndexDataContributorRoleId)
  scope: searchService
  properties: {
    principalId: managedIdentityPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', searchIndexDataContributorRoleId)
    principalType: 'ServicePrincipal'
  }
}

@description('The endpoint of the Azure OpenAI service')
output openAIEndpoint string = openAI.properties.endpoint

@description('The name of the Azure OpenAI resource')
output openAIName string = openAI.name

@description('The name of the deployed model')
output openAIModelName string = modelDeploymentName

@description('The endpoint of the Azure AI Search service')
output searchEndpoint string = 'https://${searchService.name}.search.windows.net'

@description('The name of the Azure AI Search service')
output searchName string = searchService.name

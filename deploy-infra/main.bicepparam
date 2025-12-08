using './main.bicep'

@description('The Azure region where resources will be deployed')
param location = 'uksouth'

@description('The base name for all resources')
param baseName = 'expensemgmt'

@description('The Object ID of the Azure AD administrator for SQL Server')
param adminObjectId = '' // Will be provided at deployment time

@description('The User Principal Name or Display Name of the Azure AD administrator')
param adminUsername = '' // Will be provided at deployment time

@description('The principal type of the administrator')
param adminPrincipalType = 'User'

@description('Whether to deploy GenAI resources')
param deployGenAI = false

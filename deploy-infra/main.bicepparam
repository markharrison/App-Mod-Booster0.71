using './main.bicep'

// Azure region for resource deployment
param location = 'uksouth'

// Base name for all resources
param baseName = 'expensemgmt'

// SQL administrator credentials
param sqlAdminLogin = 'sqladmin'

// Azure AD administrator details (to be provided at deployment time)
param adminObjectId = ''
param adminLogin = ''
param adminPrincipalType = 'User'

// GenAI deployment flag (false by default)
param deployGenAI = false

# Azure Architecture Diagram

This document describes the Azure services deployed by the Expense Management application.

## Architecture Overview

```mermaid
flowchart TB
    subgraph "User Access"
        User[("👤 User")]
        Browser["🌐 Browser"]
    end

    subgraph "Azure Resources"
        subgraph "Compute"
            AppService["App Service<br/>(ASP.NET 8.0)"]
        end

        subgraph "Identity"
            ManagedIdentity["User-Assigned<br/>Managed Identity"]
        end

        subgraph "Data"
            SQLServer["Azure SQL Server<br/>(Entra ID Auth Only)"]
            SQLDatabase[("Northwind<br/>Database")]
        end

        subgraph "Monitoring"
            LogAnalytics["Log Analytics<br/>Workspace"]
            AppInsights["Application<br/>Insights"]
        end

        subgraph "GenAI (Optional)"
            OpenAI["Azure OpenAI<br/>(GPT-4o)"]
            AISearch["Azure AI Search"]
        end
    end

    User --> Browser
    Browser -->|HTTPS| AppService
    
    AppService -.->|Uses| ManagedIdentity
    ManagedIdentity -->|Authenticates| SQLServer
    ManagedIdentity -->|Authenticates| OpenAI
    
    SQLServer --> SQLDatabase
    
    AppService -->|Telemetry| AppInsights
    AppInsights -->|Logs| LogAnalytics
    SQLDatabase -.->|Diagnostics| LogAnalytics
    
    AppService -.->|Chat API| OpenAI
    OpenAI -.-> AISearch

    style AppService fill:#0078D4,color:#fff
    style SQLServer fill:#0078D4,color:#fff
    style SQLDatabase fill:#0078D4,color:#fff
    style ManagedIdentity fill:#0078D4,color:#fff
    style LogAnalytics fill:#0078D4,color:#fff
    style AppInsights fill:#0078D4,color:#fff
    style OpenAI fill:#10B981,color:#fff
    style AISearch fill:#10B981,color:#fff
```

## Resource Details

### Core Resources

| Resource | Type | Purpose |
|----------|------|---------|
| App Service | Microsoft.Web/sites | Hosts the ASP.NET 8.0 web application |
| App Service Plan | Microsoft.Web/serverfarms | Standard S1 tier for hosting |
| SQL Server | Microsoft.Sql/servers | Azure SQL with Entra ID-only auth |
| SQL Database | Microsoft.Sql/servers/databases | 'Northwind' database (Basic tier) |
| Managed Identity | Microsoft.ManagedIdentity | Passwordless authentication |
| Log Analytics | Microsoft.OperationalInsights | Centralized log storage |
| Application Insights | Microsoft.Insights | APM and telemetry |

### Optional GenAI Resources

| Resource | Type | Purpose |
|----------|------|---------|
| Azure OpenAI | Microsoft.CognitiveServices/accounts | GPT-4o for chat functionality |
| AI Search | Microsoft.Search/searchServices | Semantic search (future use) |

## Security Model

```mermaid
flowchart LR
    subgraph "Authentication Flow"
        MI["Managed Identity"]
        
        subgraph "No Passwords Needed"
            SQL["Azure SQL"]
            AOAI["Azure OpenAI"]
        end
    end

    MI -->|"Entra ID Token"| SQL
    MI -->|"Entra ID Token"| AOAI
```

- **No SQL passwords**: Uses Entra ID Managed Identity authentication
- **No API keys**: Azure OpenAI uses Managed Identity with RBAC
- **Secrets-free**: All authentication via Azure AD tokens

## Deployment Scripts

```mermaid
flowchart LR
    subgraph "Deployment Flow"
        A["deploy-all.ps1"] --> B["deploy-infra/deploy.ps1"]
        B --> C["Bicep Templates"]
        B --> D["sqlcmd"]
        A --> E["deploy-app/deploy.ps1"]
        E --> F["dotnet publish"]
        E --> G["az webapp deploy"]
    end
```

## Network Flow

1. User accesses the application via HTTPS
2. App Service runs the ASP.NET application
3. Application uses Managed Identity to authenticate to:
   - Azure SQL Database (for expense data)
   - Azure OpenAI (for chat functionality)
4. All telemetry flows to Application Insights
5. Logs are stored in Log Analytics Workspace

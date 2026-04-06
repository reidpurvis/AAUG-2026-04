// ============================================================
// modules/logAnalytics.bicep
// Log Analytics Workspace for centralised monitoring
// ============================================================

@description('Resource name')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Retention period in days (30–730)')
@minValue(30)
@maxValue(730)
param retentionDays int = 90

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
output customerId string = workspace.properties.customerId

// ============================================================
// modules/storageAccount.bicep
// Storage Account with static website hosting enabled
// ============================================================

@description('Storage account name (3–24 chars, lowercase alphanumeric)')
@minLength(3)
@maxLength(24)
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Storage SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS', 'Standard_RAGRS', 'Premium_LRS'])
param sku string = 'Standard_LRS'

@description('Allow public blob access for static website')
param allowBlobPublicAccess bool = true

@description('Enable static website hosting')
param enableStaticWebsite bool = true

@description('Minimum TLS version')
param minimumTlsVersion string = 'TLS1_2'

// ── Storage Account ───────────────────────────────────────────
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: sku
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: minimumTlsVersion
    allowBlobPublicAccess: allowBlobPublicAccess
    allowSharedKeyAccess: false
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    staticWebsite: enableStaticWebsite ? {
      indexDocument: 'index.html'
      errorDocument404Path: '404.html'
    } : null
  }
}

// ── Blob Service ──────────────────────────────────────────────
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    isVersioningEnabled: true
  }
}

// ── $web Container (for static hosting) ───────────────────────
resource webContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = if (enableStaticWebsite) {
  parent: blobService
  name: '$web'
  properties: {
    publicAccess: 'Blob'
  }
}

// ── Outputs ───────────────────────────────────────────────────
output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
output webEndpoint string = enableStaticWebsite ? storageAccount.properties.primaryEndpoints.web : ''

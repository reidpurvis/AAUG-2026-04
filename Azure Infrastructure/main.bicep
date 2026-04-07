// ============================================================
// main.bicep — Cloud Paradigm Azure Landing Zone
// Orchestrates all modules for a base Azure environment
// ============================================================

targetScope = 'subscription'

// ── Parameters ───────────────────────────────────────────────
@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('Azure region for all resources')
param location string = 'australiaeast'

@description('Project / workload name used in resource naming')
param projectName string = 'cloudparadigm'

@description('Your team or cost centre tag')
param ownerTag string = 'Cloud Paradigm Pty Ltd'

@description('Deploy Key Vault?')
param deployKeyVault bool = true

@description('Deploy Virtual Network?')
param deployNetwork bool = true

@description('Deploy Log Analytics Workspace?')
param deployLogAnalytics bool = true

// ── Variables ─────────────────────────────────────────────────
var nameSuffix = '${projectName}-${environmentName}'
var tags = {
  Environment: environmentName
  Project: projectName
  Owner: ownerTag
  ManagedBy: 'GitHub Actions + Bicep'
}

// ── Resource Group ────────────────────────────────────────────
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${nameSuffix}'
  location: location
  tags: tags
}

// ── Log Analytics Workspace ───────────────────────────────────
module logAnalytics 'modules/logAnalytics.bicep' = if (deployLogAnalytics) {
  name: 'deploy-log-analytics'
  scope: rg
  params: {
    name: 'log-${nameSuffix}'
    location: location
    tags: tags
  }
}

// ── Virtual Network ───────────────────────────────────────────
module network 'modules/network.bicep' = if (deployNetwork) {
  name: 'deploy-network'
  scope: rg
  params: {
    name: 'vnet-${nameSuffix}'
    location: location
    tags: tags
    addressPrefix: environmentName == 'prod' ? '10.1.0.0/16' : '10.0.0.0/16'
  }
}

// ── Storage Account ───────────────────────────────────────────
module storage 'modules/storageAccount.bicep' = {
  name: 'deploy-storage'
  scope: rg
  params: {
    name: 'st${replace(nameSuffix, '-', '')}001'
    location: location
    tags: tags
    sku: environmentName == 'prod' ? 'Standard_GRS' : 'Standard_LRS'
  }
}

// ── Key Vault ─────────────────────────────────────────────────
module keyVault 'modules/keyVault.bicep' = if (deployKeyVault) {
  name: 'deploy-keyvault'
  scope: rg
  params: {
    name: 'kv-${nameSuffix}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// ── Outputs ───────────────────────────────────────────────────
output resourceGroupName string = rg.name
output resourceGroupId string = rg.id
output storageAccountName string = storage.outputs.storageAccountName
output keyVaultName string = deployKeyVault ? keyVault.outputs.keyVaultName : 'not deployed'
output vnetName string = deployNetwork ? network.outputs.vnetName : 'not deployed'
output logAnalyticsWorkspaceId string = deployLogAnalytics ? logAnalytics.outputs.workspaceId : 'not deployed'

// ============================================================
// main.bicep — AAUG Static Website Infrastructure
// Deploys Azure Static Web Apps for the AAUG website
// Valid SWA locations: westus2, centralus, eastus2, westeurope, eastasia
// ============================================================

targetScope = 'subscription'

// ── Parameters ───────────────────────────────────────────────
@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('Azure region for all resources')
param location string = 'eastasia'

@description('Project / workload name')
param projectName string = 'aaug'

@description('Website name (used for Static Web App)')
param websiteName string = 'aaug-website'

@description('Your team or cost centre tag')
param ownerTag string = 'AAUG'

@description('Deploy Static Web App?')
param deployStaticWebApp bool = true

@description('Deploy storage account for static hosting fallback?')
param deployStorageAccount bool = true

// ── Variables ─────────────────────────────────────────────────
var nameSuffix = '${projectName}-${environmentName}'
var staticWebAppName = '${websiteName}-${environmentName}'

// Storage account names must be globally unique (3-24 chars, lowercase alphanumeric).
// Using uniqueString on the subscription + nameSuffix avoids conflicts when
// re-deploying to a different region (e.g. after moving from eastus2 to eastasia).
var storageAccountName = 'st${take(replace(uniqueString(subscription().subscriptionId, nameSuffix), '-', ''), 16)}web'

var tags = {
  Environment: environmentName
  Project: projectName
  Owner: ownerTag
  ManagedBy: 'GitHub Actions + Bicep'
}

// ── Resource Group ────────────────────────────────────────────
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'aaug-website-rg'
  location: location
  tags: tags
}

// ── Storage Account (for fallback static hosting) ─────────────
module storage 'modules/storageAccount.bicep' = if (deployStorageAccount) {
  name: 'deploy-storage-website'
  scope: rg
  params: {
    name: storageAccountName
    location: location
    tags: tags
    sku: environmentName == 'prod' ? 'Standard_GRS' : 'Standard_LRS'
  }
}

// ── Static Web App ────────────────────────────────────────────
module staticWebApp 'modules/staticWebApp.bicep' = if (deployStaticWebApp) {
  name: 'deploy-static-web-app'
  scope: rg
  params: {
    name: staticWebAppName
    location: location
    tags: tags
    skuName: environmentName == 'prod' ? 'Standard' : 'Free'
    skuTier: environmentName == 'prod' ? 'Standard' : 'Free'
    githubOwner: 'reidpurvis'
    githubRepo: 'AAUG-2026-04'
    githubBranch: 'main'
    appLocation: 'AAUG Website App'
    outputLocation: '.'
  }
}

// ── Outputs ───────────────────────────────────────────────────
// BCP318: use ! null-assertion on conditional module outputs
output resourceGroupName string = rg.name
output resourceGroupId string = rg.id
output staticWebAppName string = deployStaticWebApp ? staticWebApp!.outputs.staticWebAppName : 'not deployed'
output staticWebAppUrl string = deployStaticWebApp ? staticWebApp!.outputs.defaultHostName : 'not deployed'
output storageAccountName string = deployStorageAccount ? storage!.outputs.storageAccountName : 'not deployed'
output storageAccountWebEndpoint string = deployStorageAccount ? storage!.outputs.webEndpoint : 'not deployed'

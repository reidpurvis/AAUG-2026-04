// ============================================================
// main.bicep — AAUG Static Website Infrastructure
// Deploys Azure Static Web Apps for the AAUG website
// ============================================================

targetScope = 'subscription'

// ── Parameters ───────────────────────────────────────────────
@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('Azure region for all resources')
param location string = 'australiaeast'

@description('Project / workload name')
param projectName string = 'aaug'

@description('Website name (used for Static Web App)')
param websiteName string = 'aaug-website'

@description('Your team or cost centre tag')
param ownerTag string = 'AAUG'

@description('Deployment timestamp — auto-set, do not override')
param deployedAt string = utcNow('yyyy-MM-dd')

@description('Deploy Static Web App?')
param deployStaticWebApp bool = true

@description('Deploy storage account for static hosting fallback?')
param deployStorageAccount bool = true

@description('GitHub repository owner')
param githubRepoOwner string = ''

@description('GitHub repository name')
param githubRepoName string = ''

@description('GitHub branch for deployment')
param githubBranch string = 'main'

// ── Variables ─────────────────────────────────────────────────
var nameSuffix = '${projectName}-${environmentName}'
var staticWebAppName = '${websiteName}-${environmentName}'
var tags = {
  Environment: environmentName
  Project: projectName
  Owner: ownerTag
  ManagedBy: 'GitHub Actions + Bicep'
  DeployedAt: deployedAt
}

// ── Resource Group ────────────────────────────────────────────
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'aaug-website-rg'
  location: location
  tags: tags
}

// ── Storage Account (for fallback static hosting) ────────────
module storage 'modules/storageAccount.bicep' = if (deployStorageAccount) {
  name: 'deploy-storage-website'
  scope: rg
  params: {
    name: 'st${replace(nameSuffix, '-', '')}web'
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
  }
}

// ── Outputs ───────────────────────────────────────────────────
output resourceGroupName string = rg.name
output resourceGroupId string = rg.id
output staticWebAppName string = deployStaticWebApp ? staticWebApp!.outputs.staticWebAppName : 'not deployed'
output staticWebAppUrl string = deployStaticWebApp ? staticWebApp!.outputs.defaultHostName : 'not deployed'
output storageAccountName string = deployStorageAccount ? storage!.outputs.storageAccountName : 'not deployed'
output storageAccountWebEndpoint string = deployStorageAccount ? storage!.outputs.primaryEndpoints.web : 'not deployed'

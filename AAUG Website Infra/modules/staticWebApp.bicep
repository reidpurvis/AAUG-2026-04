// ============================================================
// modules/staticWebApp.bicep
// Azure Static Web Apps resource
// ============================================================

@description('Static Web App name')
@minLength(1)
@maxLength(60)
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Static Web App SKU name')
@allowed(['Free', 'Standard'])
param skuName string = 'Free'

@description('Static Web App SKU tier')
@allowed(['Free', 'Standard'])
param skuTier string = 'Free'

@description('Source control repository URL (optional)')
param repositoryUrl string = ''

@description('GitHub repository branch (optional)')
param repositoryBranch string = 'main'

@description('App location in repository')
param appLocation string = '/'

@description('API location in repository (optional)')
param apiLocation string = ''

@description('Output location for build artifacts')
param outputLocation string = ''

// ── Static Web App ────────────────────────────────────────────
resource staticWebApp 'Microsoft.Web/staticSites@2023-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    provider: !empty(repositoryUrl) ? 'GitHub' : 'None'
    repositoryUrl: !empty(repositoryUrl) ? repositoryUrl : null
    branch: !empty(repositoryUrl) ? repositoryBranch : null
    buildProperties: {
      appLocation: appLocation
      apiLocation: apiLocation
      outputLocation: outputLocation
      skipGithubActionWorkflowGeneration: false
    }
    allowConfigFileUpdates: false
    stagingEnvironmentPolicy: 'Enabled'
    enterpriseGradeCdnStatus: skuTier == 'Standard' ? 'Enabled' : 'Disabled'
  }
}

// ── Outputs ───────────────────────────────────────────────────
output staticWebAppId string = staticWebApp.id
output staticWebAppName string = staticWebApp.name
output defaultHostName string = staticWebApp.properties.defaultHostname

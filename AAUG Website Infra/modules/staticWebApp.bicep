// ============================================================
// modules/staticWebApp.bicep
// Azure Static Web Apps resource with GitHub integration
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

@description('GitHub repository owner')
param githubOwner string = ''

@description('GitHub repository name')
param githubRepo string = ''

@description('GitHub repository branch')
param githubBranch string = 'main'

@description('App location in repository')
param appLocation string = 'AAUG Website App'

@description('API location in repository (optional)')
param apiLocation string = ''

@description('Output location for build artifacts')
param outputLocation string = '.'

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
    provider: (!empty(githubOwner) && !empty(githubRepo)) ? 'GitHub' : 'None'
    repositoryUrl: (!empty(githubOwner) && !empty(githubRepo)) ? 'https://github.com/${githubOwner}/${githubRepo}' : null
    branch: (!empty(githubOwner) && !empty(githubRepo)) ? githubBranch : null
    buildProperties: {
      appLocation: appLocation
      apiLocation: apiLocation
      outputLocation: outputLocation
      skipGithubActionWorkflowGeneration: true
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
output repositoryToken string = staticWebApp.listSecrets().repositoryToken


// ── Outputs ───────────────────────────────────────────────────
output staticWebAppId string = staticWebApp.id
output staticWebAppName string = staticWebApp.name
output defaultHostName string = staticWebApp.properties.defaultHostname

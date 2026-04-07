# AAUG Website Deployment Pipeline

This document describes the automated GitHub Actions pipeline for deploying the AAUG Website App to Azure Static Web Apps.

## Overview

The deployment pipeline automatically deploys the website whenever changes are pushed to the `AAUG Website App/` folder on the `main` branch. It uses GitHub Actions to authenticate with Azure, retrieve deployment credentials, and deploy to the Azure Static Web App provisioned by the Infrastructure as Code templates.

## Pipeline Architecture

```
AAUG Website App/
├── index.html          (Main event landing page)
└── artemis.html        (Artemis II mission details)
         ↓
    GitHub Push
         ↓
    .github/workflows/deploy-aaug-website.yml
         ↓
    Azure Login (OIDC)
         ↓
    Retrieve SWA Token
         ↓
    Deploy via Azure/static-web-apps-deploy@v1
         ↓
    azure-website-rg / aaug-website-{env}
         ↓
    Public Static Web App URL
```

## Prerequisites

Before the pipeline will work, you must:

### 1. Create the Azure Infrastructure

Deploy the bicep templates from `AAUG Website Infra/`:

```bash
cd "AAUG Website Infra"
ENV="dev"
az deployment sub create \
  --name "aaug-website-${ENV}" \
  --location eastus2 \
  --template-file main.bicep \
  --parameters @"parameters/parameters.${ENV}.json"
```

This creates:
- Resource Group: `aaug-website-rg`
- Static Web App: `aaug-website-{dev,staging,prod}`
- Storage Account: `stweb{projectname}` (fallback)

### 2. Configure GitHub Secrets

The pipeline requires Azure authentication credentials as GitHub Secrets. Set up Federated Identity:

```bash
# Get your GitHub repo info
GITHUB_ORG="reidpurvis"
REPO="AAUG-2026-04"

# Create Azure Service Principal with Federated Identity credentials
az ad app create --display-name "aaug-website-deployment" > app.json
CLIENT_ID=$(jq -r '.appId' app.json)
OBJECT_ID=$(jq -r '.id' app.json)

# Create service principal
az ad sp create --id $CLIENT_ID

# Set subscription context
SUBSCRIPTION=$(az account show --query id -o tsv)

# Assign Contributor role to the Static Web App resource group
az role assignment create \
  --role "Contributor" \
  --assignee-object-id=$OBJECT_ID \
  --resource-group aaug-website-rg

# Create Federated Identity credential
az identity federated-credential create \
  --name "github-deployment" \
  --identity-name "<identity-name>" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:${GITHUB_ORG}/${REPO}:ref:refs/heads/main"
```

Add these GitHub Secrets (Settings → Secrets and variables → Actions):
- `AZURE_CLIENT_ID`: Service Principal Client ID
- `AZURE_TENANT_ID`: Azure Tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure Subscription ID

### 3. Enable GitHub Integration on Static Web App

The Static Web App resource needs GitHub integration to retrieve the deployment token:

```bash
az staticwebapp github-token validate \
  --name aaug-website-dev \
  --resource-group aaug-website-rg \
  --token <github-token>
```

## Deployment Triggers

### Automatic (Push-based)
The pipeline triggers automatically when:
- Changes are pushed to the `main` branch
- **AND** files within `AAUG Website App/` or this workflow file are modified

```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'AAUG Website App/**'
      - '.github/workflows/deploy-aaug-website.yml'
```

### Manual (Workflow Dispatch)
Manually trigger deployments to specific environments:

```bash
gh workflow run deploy-aaug-website.yml \
  --ref main \
  -f environment=prod
```

Or via the GitHub UI: **Actions** → **Deploy AAUG Website** → **Run workflow**

## Environment Mapping

| Branch/Trigger | Environment | Static Web App | URL |
|---|---|---|---|
| `push main` | `dev` | `aaug-website-dev` | `https://aaug-website-dev.{region}.azurestaticapps.net` |
| `dispatch prod` | `prod` | `aaug-website-prod` | `https://aaug-website-prod.{region}.azurestaticapps.net` |

## Deployment Steps

1. **Checkout** - Gets the latest code
2. **Determine Environment** - Selects env based on branch/input
3. **Azure Login** - Authenticates using Federated Identity (OIDC)
4. **Retrieve Token** - Gets the Static Web App deployment token via Azure CLI
5. **Get App URL** - Fetches the Public URL for output
6. **Deploy** - Uses `azure/static-web-apps-deploy@v1` to upload files
7. **Report** - Outputs deployment URL and links to GitHub summary

## Network & Security

- **Static Web App** runs in Azure's global CDN
- **HTTPS** enabled by default with Microsoft-issued certificates
- **GitHub Secrets** stored securely using GitHub's encryption
- **Federated Identity** avoids storing long-lived credentials
- **Deployment Token** is short-lived and retrieved just-in-time

## Monitoring & Troubleshooting

### View Deployment Logs
1. Go to your GitHub repo
2. Click **Actions** → **Deploy AAUG Website**
3. Click the workflow run to see detailed logs

### Common Issues

**Issue**: "Static Web App not found"
- Ensure`RESOURCE_GROUP` matches your bicep deployment
- Verify the app name matches: `aaug-website-{dev|staging|prod}`

**Issue**: "Deployment token unavailable"
- Check GitHub integration is enabled on the Static Web App
- Verify service principal has `Contributor` role on resource group

**Issue**: "Azure Login failed"
- Confirm GitHub Secrets are set correctly
- Check Federated Identity credential subject matches: `repo:{ORG}/{REPO}:ref:refs/heads/main`

**Issue**: Assets not loading on deployed site (HTTP 404)
- Verify files are in `AAUG Website App/` directory
- Check `app_location` and `output_location` match your structure
- Static Web Apps expects `index.html` at the root

## Manual Deployment (CLI)

If the pipeline fails, you can deploy manually:

```bash
# Get the deployment token
TOKEN=$(az staticwebapp list -g aaug-website-rg \
  --query "[?name=='aaug-website-dev'].repositoryToken" -o tsv)

# Deploy using Static Web Apps CLI
npm install -g @azure/static-web-apps-cli

swa deploy \
  --app-name aaug-website-dev \
  appLocation ./AAUG\ Website\ App \
  --deployment-token $TOKEN
```

## Files Modified

- `.github/workflows/deploy-aaug-website.yml` - GitHub Actions pipeline
- `AAUG Website App/index.html` - Main event page
- `AAUG Website App/artemis.html` - Mission details page

## URL References

After deployment, access the website at:

```
Dev:     https://aaug-website-dev.{region}.azurestaticapps.net
Prod:    https://aaug-website-prod.{region}.azurestaticapps.net
```

Pages:
- Home: `/index.html`
- Artemis II: `/artemis.html`

## Cost Optimization

Azure Static Web Apps includes:
- **Free tier**: 1 app per resource group, 100 GB/month traffic
- **Standard tier**: Multiple apps, premium features, custom domains

The dev environment uses the Free tier. Upgrade to Standard for production if needed:

```bash
az staticwebapp update -n aaug-website-prod -g aaug-website-rg --sku Standard
```

## Next Steps

1. ✅ Review the GitHub Actions workflow
2. ✅ Set up Azure authentication secrets
3. ✅ Deploy the Azure infrastructure (bicep)
4. ✅ Push changes to trigger the first deployment
5. ✅ Access the deployed website URL

For issues or questions, check the deployment logs in GitHub Actions > Deploy AAUG Website.

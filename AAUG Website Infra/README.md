# AAUG Website Infrastructure

Azure Bicep deployment scripts for the AAUG Static Website infrastructure.

## Overview

This folder contains Infrastructure-as-Code (IaC) using **Azure Bicep** to deploy and manage the AAUG website hosting infrastructure on Azure.

### Resources Deployed

- **Azure Static Web Apps** (`modules/staticWebApp.bicep`)
  - Serverless hosting for static websites
  - Built-in CI/CD integration with GitHub
  - Free SSL/TLS certificates
  - Global CDN included in Standard tier

- **Azure Storage Account** (`modules/storageAccount.bicep`)
  - Fallback static website hosting
  - Blob storage for static content
  - Optional: Can serve as backup if Static Web Apps is unavailable

### Resource Group

All resources are deployed to a new resource group: **`aaug-website-rg`**

## Directory Structure

```
AAUG Website Infra/
├── main.bicep                          # Main orchestration template
├── modules/
│   ├── staticWebApp.bicep             # Azure Static Web Apps module
│   └── storageAccount.bicep           # Storage account with static hosting
├── parameters/
│   ├── parameters.dev.json            # Development environment parameters
│   ├── parameters.staging.json        # Staging environment parameters
│   └── parameters.prod.json           # Production environment parameters
├── scripts/
│   └── deploy.sh                      # Bash deployment script
└── README.md                           # This file
```

## Prerequisites

- **Azure CLI**: Install from https://docs.microsoft.com/cli/azure/install-azure-cli
- **Bicep CLI**: Included with Azure CLI v2.36+
  - Verify with: `az bicep version`
- **Azure Subscription**: With appropriate permissions
- **Bash Shell**: For running deployment scripts

## Authentication

Authenticate with Azure before deploying:

```bash
az login
az account set --subscription <subscription-id>
```

## Deployment

### Quick Start

Deploy to development environment:

```bash
./scripts/deploy.sh dev
```

Deploy to staging:

```bash
./scripts/deploy.sh staging
```

Deploy to production:

```bash
./scripts/deploy.sh prod
```

### Manual Deployment (without script)

```bash
az deployment sub create \
  --location australiaeast \
  --template-file main.bicep \
  --parameters @parameters/parameters.dev.json
```

### Deployment Parameters

Each environment has its own parameter file:

- **`parameters.dev.json`** — Development (Free tier SWA, LRS storage)
- **`parameters.staging.json`** — Staging (Standard tier SWA, GRS storage)
- **`parameters.prod.json`** — Production (Standard tier SWA, GRS storage)

Customize these files before deployment:

```json
{
  "parameters": {
    "environmentName": { "value": "dev" },
    "location": { "value": "australiaeast" },
    "githubRepoOwner": { "value": "your-github-username" },
    "githubRepoName": { "value": "your-repo-name" },
    "githubBranch": { "value": "main" }
  }
}
```

## Configuration

### GitHub Integration (Optional)

To enable automatic CI/CD with GitHub, update the parameters:

```json
"githubRepoOwner": { "value": "your-github-org" },
"githubRepoName": { "value": "your-website-repo" },
"githubBranch": { "value": "main" }
```

GitHub Actions workflow will be auto-generated upon deployment.

### Static Web App Tier

- **Free**: Development/testing, single staging environment
- **Standard**: Production, multiple staging environments, custom domains, custom auth providers

Change in the respective `parameters.<env>.json`:

```json
"skuName": { "value": "Standard" },
"skuTier": { "value": "Standard" }
```

## Output

After successful deployment, the script displays:

```
✓ Deployment completed successfully!

ℹ Deployment outputs:

Name                          Type    Value
─────────────────────────────────────────────────────────────
resourceGroupName             string  aaug-website-rg
staticWebAppName              string  aaug-website-dev
staticWebAppUrl               string  https://polite-flower-xxxx.australiaeast.azurestaticapps.net
storageAccountName            string  staaugwebdev
storageAccountWebEndpoint     string  https://staaugwebdev.z26.web.core.windows.net/
```

## Outputs Explained

| Output | Description |
|--------|-------------|
| `resourceGroupName` | Name of the created resource group (always `aaug-website-rg`) |
| `staticWebAppName` | Azure Static Web App resource name |
| `staticWebAppUrl` | Default HTTPS endpoint for your website |
| `storageAccountName` | Storage account name (if deployed) |
| `storageAccountWebEndpoint` | Static website endpoint on storage account |

## Updating Resources

To update existing resources, modify the relevant `.json` parameter file and redeploy:

```bash
./scripts/deploy.sh dev
```

Bicep will detect changes and apply updates accordingly.

## Deleting Resources

To remove the resource group and all resources:

```bash
az group delete --name aaug-website-rg --yes --no-wait
```

Or via Azure Portal:
1. Go to **Resource Groups**
2. Select **aaug-website-rg**
3. Click **Delete resource group**

## Troubleshooting

### Deployment fails with "Invalid Bicep file"

Validate the Bicep syntax:

```bash
az bicep build --file main.bicep
```

### "Not authenticated with Azure"

Run authentication:

```bash
az login
```

### "Resource already exists"

If a resource group or resource already exists and conflicts:

```bash
# List all resource groups
az group list -o table

# Check specific resource group
az group exists --name aaug-website-rg
```

### Static Web App URL not accessible

- Wait 5-10 minutes for DNS propagation
- Check resource group in Azure Portal
- Verify network access and firewall rules
- Check Static Web App build logs

## Best Practices

1. **Parameter Files**: Keep sensitive data (passwords, tokens) out of JSON files
   - Use Key Vault for secrets instead
   - Use Azure CLI secrets management

2. **GitHub Tokens**: Use GitHub personal access tokens (classic) with `public_repo` scope minimum
   - Store in Azure Key Vault
   - Reference in Bicep templates

3. **Versioning**: Tag bicep version in parameters or scripts
   - Example: `bicep-version: "0.23+"`

4. **Environment Separation**: Maintain separate deployments for dev/staging/prod
   - Different Azure subscriptions (ideal)
   - Different resource groups (minimum)
   - Different parameter files (always)

5. **Monitoring**: Enable Azure Monitor diagnostics
   - Application Insights for Static Web Apps
   - Storage analytics for fallback storage

## References

- [Azure Static Web Apps Documentation](https://learn.microsoft.com/azure/static-web-apps/)
- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Storage Static Websites](https://learn.microsoft.com/azure/storage/blobs/storage-blob-static-website)

## Support

For issues or questions:
- Check deployment logs: `az deployment sub show --name <deployment-name>`
- Review Azure Portal for resource details
- Consult Azure documentation links above

---

**Last Updated**: 2026-04-07
**Maintained By**: AAUG Team

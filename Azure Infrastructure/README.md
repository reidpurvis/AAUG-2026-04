# Azure Infrastructure

Bicep templates for deploying a base Azure landing zone, deployed via GitHub Actions.

## Structure

```
Azure Infrastructure/
├── main.bicep                        # Root orchestration template (subscription scope)
├── modules/
│   ├── logAnalytics.bicep            # Log Analytics Workspace
│   ├── network.bicep                 # Virtual Network + subnets
│   ├── storageAccount.bicep          # Storage Account (hardened)
│   └── keyVault.bicep                # Key Vault + diagnostics
└── parameters/
    ├── dev.parameters.json           # Dev environment values
    └── prod.parameters.json          # Prod environment values
```

## What Gets Deployed

| Resource | Dev SKU | Prod SKU |
|---|---|---|
| Resource Group | `rg-cloudparadigm-dev` | `rg-cloudparadigm-prod` |
| Log Analytics Workspace | PerGB2018, 90-day retention | PerGB2018, 90-day retention |
| Virtual Network | `10.0.0.0/16` (3 subnets) | `10.1.0.0/16` (3 subnets) |
| Storage Account | Standard_LRS | Standard_GRS |
| Key Vault | Standard, RBAC, soft-delete | Standard, RBAC, purge-protected |

## Prerequisites

### Azure — Federated Identity (OIDC)

Create a service principal and configure OIDC federation for GitHub Actions (no stored secrets):

```bash
# 1. Create app registration
az ad app create --display-name "sp-github-cloudparadigm"

# 2. Create service principal
az ad sp create --id <app-id>

# 3. Assign Contributor role at subscription scope
az role assignment create \
  --role Contributor \
  --assignee <app-id> \
  --scope /subscriptions/<subscription-id>

# 4. Add federated credential (in Azure Portal → App Registration → Certificates & secrets → Federated credentials)
#    Entity: Branch, Branch: main, Issuer: https://token.actions.githubusercontent.com
```

### GitHub Secrets

Add these three secrets to your repository (Settings → Secrets → Actions):

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | App Registration Client ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target Subscription ID |

### GitHub Environments

Create `dev` and `prod` environments in GitHub (Settings → Environments).  
For `prod`, add a **required reviewer** approval gate.

## Running the Pipeline

### Automatic
Push any change under `Azure Infrastructure/` to `main` → deploys to **dev** automatically.

### Manual
Go to **Actions → Deploy Azure Infrastructure → Run workflow**, choose environment and region.

### Pull Request
Opening a PR against `main` runs **validate + what-if only** — no deployment.

## Local Development

```bash
# Install Bicep CLI
az bicep install

# Lint
az bicep lint --file main.bicep

# Validate (requires Azure login)
az deployment sub validate \
  --name test-validate \
  --location australiaeast \
  --template-file main.bicep \
  --parameters parameters/dev.parameters.json

# What-if
az deployment sub what-if \
  --name test-whatif \
  --location australiaeast \
  --template-file main.bicep \
  --parameters parameters/dev.parameters.json

# Deploy
az deployment sub create \
  --name test-deploy \
  --location australiaeast \
  --template-file main.bicep \
  --parameters parameters/dev.parameters.json
```

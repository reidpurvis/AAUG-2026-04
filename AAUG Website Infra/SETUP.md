# ✅ Pipeline Configuration Checklist

Quick checklist to enable the AAUG Website Infrastructure CI/CD pipeline.

## Prerequisites

- [ ] Azure subscription with appropriate permissions
- [ ] GitHub repository with Admin/Settings access
- [ ] Azure CLI installed locally
- [ ] GitHub CLI installed (optional but recommended)

## Step 1: Set Up Azure Service Principal

### Option A: Automated (Recommended)

```bash
cd "Azure Infrastructure"
./scripts/setup-sp.sh
```

This creates and configures everything automatically.

### Option B: Manual Setup

Follow steps in `Azure Infrastructure/README.md` under "Service Principal Setup"

**Verify**:
```bash
# Confirm Service Principal exists
az ad app list --display-name "GitHub-AAUG-Website"

# Confirm OIDC federation
az identity federated-credentials list --resource-group <rg> --identity-name <identity-name>
```

## Step 2: Configure GitHub Secrets

### Automated Configuration

```bash
./AAUG\ Website\ Infra/scripts/configure-github-pipeline.sh your-org/your-repo
```

### Manual Configuration

1. **Add Secrets**
   - Visit: `https://github.com/your-org/your-repo/settings/secrets/actions`
   - Add three new repository secrets:
     - `AZURE_CLIENT_ID` — From Azure Service Principal
     - `AZURE_TENANT_ID` — Your Azure AD tenant ID
     - `AZURE_SUBSCRIPTION_ID` — Your Azure subscription ID

   **Get values**:
   ```bash
   az account show --query "id, tenantId" -o json
   az ad app list --display-name "GitHub-AAUG-Website" --query "[0].id" -o tsv
   ```

2. **Verify Secrets Added**
   - Refresh the page, should see 3 secrets listed

## Step 3: Create GitHub Environments

1. Visit: `https://github.com/your-org/your-repo/settings/environments`

2. Create three environments (if not auto-created):

   **Environment 1: `dev`**
   - Deployment branches: `main`
   - Protection rules: None
   - ✓ Save

   **Environment 2: `staging`**
   - Deployment branches: `main`
   - Protection rules: Required reviewers (optional)
   - ✓ Save

   **Environment 3: `prod`**
   - Deployment branches: `main`
   - Protection rules: Required reviewers (recommended)
   - ✓ Save

## Step 4: Enable Repository Settings

1. Visit: `https://github.com/your-org/your-repo/settings/actions`

   - [ ] Allow all actions and reusable workflows
   - [ ] Fork pull request workflows from outside collaborators

2. Visit: `.github/workflows/deploy-website-infra.yml`

   - [ ] Workflow exists and is readable in GitHub

## Step 5: Test the Pipeline

### Create a Test Branch

```bash
git checkout -b feature/test-pipeline
git pull origin main
```

### Trigger Validation (Pull Request)

```bash
# Make a small change
echo "# Pipeline test" >> "AAUG Website Infra/README.md"

# Commit and push
git add "AAUG Website Infra/README.md"
git commit -m "test: validate pipeline"
git push origin feature/test-pipeline
```

Then:
1. Create a pull request on GitHub
2. Go to **Actions** tab
3. Watch "Deploy AAUG Website Infrastructure" workflow run
4. Verify **Validate** job completes successfully

✓ **Expected Result**: Validation passes, no deployment (since it's a PR)

### Trigger Deployment (Merge to Main)

After PR validation passes:
1. Merge the PR to `main`
2. Go to **Actions** tab
3. Watch the same workflow run again
4. Verify both **Validate** and **Deploy** jobs complete

✓ **Expected Result**: Both jobs pass, resources deployed to Azure

### Verify Deployment in Azure

```bash
az group show --name aaug-website-rg --query "[name, location]" -o table
az resource list --resource-group aaug-website-rg -o table
```

Should show:
- Resource Group: `aaug-website-rg`
- Static Web App: `aaug-website-dev`
- Storage Account: `staaugwebdev`

## Step 6: Enable Auto-Deployment (Optional)

The pipeline will now automatically deploy whenever you:

- **Push** to `main` with changes in `AAUG Website Infra/` folder
- **Manually trigger** from GitHub Actions UI
- **Create a PR** (validation only, no deployment)

No additional setup needed! 🎉

## Troubleshooting

### Workflow Not Running

**Check**:
1. Moved files to correct location: `AAUG Website Infra/`
2. Changes are on `main` branch
3. Workflow file exists at: `.github/workflows/deploy-website-infra.yml`
4. Repository Actions are enabled

**Fix**:
```bash
# Verify workflow is valid
gh workflow list --repo your-org/your-repo

# Check recent activity
gh run list --repo your-org/your-repo --limit 10
```

### Authentication Failed

**Symptoms**: "AADSTS70025" or "OIDC token exchange failed"

**Check**:
1. Secrets are correct:
   ```bash
   gh secret list --repo your-org/your-repo
   ```

2. Service Principal has Contributor role:
   ```bash
   az role assignment list --assignee <client-id>
   ```

3. OIDC federation is configured:
   ```bash
   az identity federated-credentials show --resource-group <rg> --identity-name <identity>
   ```

**Fix**:
```bash
# Re-run setup script
./Azure\ Infrastructure/scripts/setup-sp.sh

# Or run fix script
./Azure\ Infrastructure/scripts/fix-federated-credentials.sh
```

### Validation Failures

**Symptoms**: "Lint validation failed" or "Deployment validation failed"

**Check**:
```bash
# Validate locally
az bicep lint "AAUG Website Infra/main.bicep"
az bicep lint "AAUG Website Infra/modules/staticWebApp.bicep"
az bicep lint "AAUG Website Infra/modules/storageAccount.bicep"

# Validate parameters
az deployment sub validate \
  --location australiaeast \
  --template-file "AAUG Website Infra/main.bicep" \
  --parameters "@AAUG Website Infra/parameters/parameters.dev.json"
```

**Common Issues**:
- Parameter file names must match environment: `parameters.{env}.json`
- Bicep syntax errors (check linting output)
- Missing or renamed parameters

### Deployment Hangs

**If workflow seems stuck**:

1. Check GitHub Actions UI for status
2. GitHub has 6-hour job timeout limit
3. Can manually cancel from Actions tab
4. Review logs for what step is hanging

**Common causes**:
- Large resource creations (usually completes in 5-10 minutes)
- Network connectivity issues
- Azure service rate limiting

## Next Steps

- [ ] Read `AAUG Website Infra/PIPELINE.md` for detailed documentation
- [ ] Read `AAUG Website Infra/README.md` for infrastructure details
- [ ] Customize parameters in `AAUG Website Infra/parameters/` for your needs
- [ ] Add branch protection rules to `main` (require PR reviews)
- [ ] Set up Slack/Teams notifications (optional)
- [ ] Configure backup and disaster recovery

## Support

**Documentation**:
- `AAUG Website Infra/PIPELINE.md` — Pipeline details & troubleshooting
- `AAUG Website Infra/README.md` — Infrastructure overview
- `.github/workflows/deploy-website-infra.yml` — Workflow definition

**External Resources**:
- [GitHub Actions Docs](https://docs.github.com/actions)
- [Azure/login Action OIDC Docs](https://github.com/azure/login)
- [Azure Bicep Docs](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

---

**Your infrastructure is ready to deploy! 🚀**

Once secrets and environments are configured, the pipeline will automatically deploy whenever you push to main.

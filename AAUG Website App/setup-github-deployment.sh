#!/bin/bash
set -e

echo "🔧 Setting up AAUG Website deployment..."
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check Azure CLI
if ! command -v az &> /dev/null; then
  echo "❌ Azure CLI not found. Install from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
  exit 1
fi
echo "✅ Azure CLI found"

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
  echo "❌ GitHub CLI not found. Install from: https://cli.github.com/"
  exit 1
fi
echo "✅ GitHub CLI found"

# Check logged into Azure
if ! az account show &>/dev/null; then
  echo "❌ Not logged into Azure. Run: az login"
  exit 1
fi
echo "✅ Logged into Azure"

# Get current Azure subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "  Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo ""

# Get GitHub info
GH_USER=$(gh api user -q .login)
GH_REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "✅ Logged into GitHub"
echo "  Repository: $GH_REPO"
echo "  User: $GH_USER"
echo ""

# Create resource group if it doesn't exist
RG_NAME="aaug-website-rg"
LOCATION="eastus2"

echo "📦 Setting up Azure resources..."
if az group exists -n "$RG_NAME" -o tsv | grep -q true; then
  echo "✅ Resource Group exists: $RG_NAME"
else
  echo "📝 Creating Resource Group: $RG_NAME"
  az group create -n "$RG_NAME" -l "$LOCATION"
  echo "✅ Resource Group created"
fi
echo ""

# Deploy Bicep infrastructure
echo "🏗️  Deploying infrastructure (this may take 2-3 minutes)..."
cd "AAUG Website Infra"

for ENV in dev staging prod; do
  echo "  Deploying $ENV environment..."

  az deployment group create \
    --name "aaug-website-$ENV" \
    --resource-group "$RG_NAME" \
    --template-file main.bicep \
    --parameters \
      environmentName="$ENV" \
      location="$LOCATION" \
      projectName="aaug" \
      websiteName="aaug-website" \
      ownerTag="AAUG" \
      deployStaticWebApp=true \
      deployStorageAccount=true \
    --no-wait
done

cd ..
echo "✅ Infrastructure deployment initiated (running in background)"
echo ""

# Configure GitHub secrets
echo "🔐 Setting up GitHub secrets..."

# Check if secrets are already set
if gh secret list -R "$GH_REPO" --json name -q | grep -q AZURE_SUBSCRIPTION_ID; then
  echo "✅ Secrets already configured"
else
  echo "📝 Configuring Azure secrets..."

  # Create service principal for GitHub deployment
  echo "  Creating service principal..."

  PRINCIPAL_NAME="github-aaug-website-deploy"

  # Check if principal already exists
  PRINCIPAL=$(az ad sp list --display-name "$PRINCIPAL_NAME" --query "[0].id" -o tsv 2>/dev/null || echo "")

  if [ -z "$PRINCIPAL" ]; then
    # Create new service principal
    az ad sp create-for-rbac \
      --name "$PRINCIPAL_NAME" \
      --role Contributor \
      --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME" \
      --output json > /tmp/sp.json

    TENANT_ID=$(jq -r '.tenant' /tmp/sp.json)
    CLIENT_ID=$(jq -r '.clientId' /tmp/sp.json)

    echo "  ✅ Service Principal created: $PRINCIPAL_NAME"
  else
    echo "  ℹ️  Service principal already exists"
    TENANT_ID=$(az account show --query tenantId -o tsv)
    CLIENT_ID=$(az ad sp show --id "$PRINCIPAL" --query appId -o tsv)
  fi

  # Set secrets
  echo "  Setting GitHub secrets..."
  gh secret set AZURE_CLIENT_ID -b"$CLIENT_ID" -R "$GH_REPO"
  gh secret set AZURE_TENANT_ID -b"$TENANT_ID" -R "$GH_REPO"
  gh secret set AZURE_SUBSCRIPTION_ID -b"$SUBSCRIPTION_ID" -R "$GH_REPO"

  echo "  ✅ GitHub secrets configured:"
  echo "    - AZURE_CLIENT_ID"
  echo "    - AZURE_TENANT_ID"
  echo "    - AZURE_SUBSCRIPTION_ID"
fi
echo ""

# Summary
echo "╔═════════════════════════════════════════════════════════════╗"
echo "║          ✅ SETUP COMPLETE - READY TO DEPLOY! 🚀            ║"
echo "╚═════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 Next Steps:"
echo ""
echo "1. Verify infrastructure is deployed:"
echo "   az staticwebapp list -g aaug-website-rg"
echo ""
echo "2. Make changes to AAUG Website App/"
echo ""
echo "3. Commit and push to trigger automatic deployment:"
echo "   git add AAUG\ Website\ App/"
echo "   git commit -m 'Update website'"
echo "   git push origin main"
echo ""
echo "4. Watch deployment in GitHub Actions:"
echo "   gh run list --workflow=deploy-aaug-website.yml"
echo ""
echo "5. Visit your live website when deployed! 🎉"
echo ""
echo "💡 Tips:"
echo "  - Pipeline triggers automatically on changes to AAUG Website App/"
echo "  - Deployment takes ~2-3 minutes from push to live"
echo "  - Check PIPELINE_GUIDE.md for detailed documentation"
echo "  - View logs: gh run view <run-id> --log"
echo ""

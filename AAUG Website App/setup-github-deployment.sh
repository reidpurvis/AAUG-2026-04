#!/bin/bash
set -e

# AAUG Website Deployment — GitHub Actions Setup Script
# This script configures Azure authentication for the GitHub Actions pipeline

echo "🚀 AAUG Website Deployment Pipeline Setup"
echo "==========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found. Please install it first:${NC}"
    echo "   https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI not found. Please install it first:${NC}"
    echo "   https://cli.github.com"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq not found. Please install it first:${NC}"
    echo "   macOS: brew install jq"
    echo "   Ubuntu: sudo apt-get install jq"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites installed${NC}"
echo ""

# Get current Azure context
echo -e "${BLUE}Current Azure subscription:${NC}"
SUBSCRIPTION=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "  Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION)"
echo "  Tenant: $TENANT_ID"
echo ""

# Get GitHub repo info
echo -e "${BLUE}GitHub repository:${NC}"
GITHUB_REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
GITHUB_ORG=$(echo $GITHUB_REPO | cut -d'/' -f1)
REPO_NAME=$(echo $GITHUB_REPO | cut -d'/' -f2)
echo "  Repository: $GITHUB_REPO"
echo ""

# Confirm Azure infrastructure
echo -e "${YELLOW}⚠️  Ensuring Azure infrastructure exists...${NC}"
RESOURCE_GROUP="aaug-website-rg"
if az group exists -n $RESOURCE_GROUP -o tsv | grep -q true; then
    echo -e "${GREEN}✅ Resource Group found: $RESOURCE_GROUP${NC}"
else
    echo -e "${RED}❌ Resource Group not found: $RESOURCE_GROUP${NC}"
    echo ""
    echo "Please run the Bicep deployment first:"
    echo "  cd AAUG\\ Website\\ Infra"
    echo "  ./deploy.sh"
    echo ""
    read -p "Press Enter once you've deployed the infrastructure, or Ctrl+C to exit: "
fi

# Check for Static Web App
SWA_NAME=$(az staticwebapp list -g $RESOURCE_GROUP --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -z "$SWA_NAME" ]; then
    echo -e "${RED}❌ No Static Web App found in $RESOURCE_GROUP${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Static Web App found: $SWA_NAME${NC}"
echo ""

# Create Service Principal
echo -e "${BLUE}Creating Azure Service Principal...${NC}"
SP_NAME="aaug-website-github-deployment"
SP_DISPLAY_NAME="AAUG Website GitHub Deployment"

echo "  Name: $SP_DISPLAY_NAME"

# Check if SP already exists
EXISTING_SP=$(az ad app list --filter "displayName eq '$SP_DISPLAY_NAME'" --query "[0]" -o json 2>/dev/null || echo "")

if [ "$EXISTING_SP" != "" ]; then
    echo -e "${YELLOW}⚠️  Service Principal already exists, updating...${NC}"
    CLIENT_ID=$(echo $EXISTING_SP | jq -r '.appId')
    OBJECT_ID=$(echo $EXISTING_SP | jq -r '.id')
else
    # Create new app registration
    APP_OUTPUT=$(az ad app create --display-name "$SP_DISPLAY_NAME" -o json)
    CLIENT_ID=$(echo $APP_OUTPUT | jq -r '.appId')
    OBJECT_ID=$(echo $APP_OUTPUT | jq -r '.id')

    # Create service principal
    az ad sp create --id $CLIENT_ID > /dev/null
    echo "  Created: $CLIENT_ID"
fi

echo -e "${GREEN}✅ Service Principal: $CLIENT_ID${NC}"
echo ""

# Assign role
echo -e "${BLUE}Assigning Contributor role to resource group...${NC}"
ROLE_EXISTS=$(az role assignment list --assignee $CLIENT_ID \
    --role "Contributor" \
    --resource-group $RESOURCE_GROUP \
    --query "[0]" 2>/dev/null || echo "")

if [ "$ROLE_EXISTS" = "" ]; then
    az role assignment create \
        --role "Contributor" \
        --assignee-object-id $OBJECT_ID \
        --resource-group $RESOURCE_GROUP > /dev/null
    echo -e "${GREEN}✅ Role assigned${NC}"
else
    echo -e "${GREEN}✅ Role already assigned${NC}"
fi
echo ""

# Create Federated Identity Credential
echo -e "${BLUE}Setting up Federated Identity for GitHub Actions...${NC}"

FEDERATED_NAME="github-deployment-${REPO_NAME}"
ISSUER="https://token.actions.githubusercontent.com"
SUBJECT="repo:${GITHUB_REPO}:ref:refs/heads/main"

echo "  Issuer: $ISSUER"
echo "  Subject: $SUBJECT"

# Check if credential already exists
EXISTING_CRED=$(az identity federated-credential list \
    --name $FEDERATED_NAME \
    --resource-group $RESOURCE_GROUP \
    --identity-name $FEDERATED_NAME \
    --query "[0]" 2>/dev/null || echo "")

# For service principal, we need to create it differently
# Using the service principal directly with federated credentials
az ad app federated-credential create \
    --id $OBJECT_ID \
    --parameters "{ \
        \"name\": \"$FEDERATED_NAME\", \
        \"issuer\": \"$ISSUER\", \
        \"subject\": \"$SUBJECT\", \
        \"audiences\": [\"api://AzureADTokenExchange\"] \
    }" 2>/dev/null || true

echo -e "${GREEN}✅ Federated Identity configured${NC}"
echo ""

# Set GitHub Secrets
echo -e "${BLUE}Configuring GitHub Secrets...${NC}"

# Check if already set
echo "  Setting AZURE_CLIENT_ID..."
gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID" 2>/dev/null || \
  gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID"

echo "  Setting AZURE_TENANT_ID..."
gh secret set AZURE_TENANT_ID --body "$TENANT_ID" 2>/dev/null || \
  gh secret set AZURE_TENANT_ID --body "$TENANT_ID"

echo "  Setting AZURE_SUBSCRIPTION_ID..."
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION" 2>/dev/null || \
  gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION"

echo -e "${GREEN}✅ GitHub Secrets configured${NC}"
echo ""

# Summary
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Service Principal:"
echo "  Client ID: $CLIENT_ID"
echo "  Tenant ID: $TENANT_ID"
echo ""
echo "GitHub Secrets added to: $GITHUB_REPO"
echo "  AZURE_CLIENT_ID"
echo "  AZURE_TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID"
echo ""
echo "Next steps:"
echo "  1. Push a change to AAUG Website App/ to trigger deployment"
echo "  2. Check GitHub Actions for deployment status"
echo "  3. Access your website at the generated URL"
echo ""
echo "To manually trigger deployment:"
echo "  gh workflow run deploy-aaug-website.yml --ref main -f environment=dev"
echo ""
echo "To view deployment logs:"
echo "  gh run list --workflow=deploy-aaug-website.yml --limit 1"
echo ""

#!/usr/bin/env bash
# ==============================================================
# setup-service-principal.sh
# Creates an Entra ID App Registration + Service Principal
# with OIDC federated credentials for GitHub Actions.
#
# Usage:
#   chmod +x setup-service-principal.sh
#   ./setup-service-principal.sh
#
# Requirements:
#   - Azure CLI (az) installed and logged in
#   - GitHub CLI (gh) installed and authenticated  [optional]
#   - Sufficient permissions: Application Administrator + 
#     Owner/User Access Administrator on the subscription
# ==============================================================

set -euo pipefail

# ── Config — edit these ───────────────────────────────────────
APP_NAME="sp-github-aaug-2026-04"
GITHUB_ORG="reidpurvis"
GITHUB_REPO="AAUG-2026-04"
ROLE="Contributor"
# ─────────────────────────────────────────────────────────────

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ ${NC}$1"; }
success() { echo -e "${GREEN}✅ ${NC}$1"; }
warn()    { echo -e "${YELLOW}⚠  ${NC}$1"; }
error()   { echo -e "${RED}❌ ${NC}$1"; exit 1; }
section() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE} $1${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}"; }

# ── Pre-flight checks ─────────────────────────────────────────
section "Pre-flight checks"

command -v az >/dev/null 2>&1 || error "Azure CLI not found. Install from https://aka.ms/installazurecli"
az account show >/dev/null 2>&1   || error "Not logged in. Run: az login"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

info "Subscription : ${SUBSCRIPTION_NAME}"
info "Subscription ID : ${SUBSCRIPTION_ID}"
info "Tenant ID       : ${TENANT_ID}"
info "App name        : ${APP_NAME}"
info "GitHub repo     : ${GITHUB_ORG}/${GITHUB_REPO}"

echo ""
read -p "Proceed with these settings? [y/N] " -r
[[ "$REPLY" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# ── Step 1: Create App Registration ──────────────────────────
section "Step 1 — Create App Registration"

# Check if already exists
EXISTING_APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || true)

if [[ -n "$EXISTING_APP_ID" && "$EXISTING_APP_ID" != "None" ]]; then
  warn "App '${APP_NAME}' already exists (App ID: ${EXISTING_APP_ID}). Using existing."
  APP_ID="$EXISTING_APP_ID"
else
  APP_ID=$(az ad app create \
    --display-name "$APP_NAME" \
    --query appId -o tsv)
  success "App Registration created. App ID: ${APP_ID}"
fi

# ── Step 2: Create Service Principal ─────────────────────────
section "Step 2 — Create Service Principal"

EXISTING_SP=$(az ad sp list --filter "appId eq '${APP_ID}'" --query "[0].id" -o tsv 2>/dev/null || true)

if [[ -n "$EXISTING_SP" && "$EXISTING_SP" != "None" ]]; then
  warn "Service Principal already exists. Skipping creation."
  SP_OBJECT_ID="$EXISTING_SP"
else
  SP_OBJECT_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)
  success "Service Principal created. Object ID: ${SP_OBJECT_ID}"
  # Brief pause for AAD propagation
  info "Waiting 20s for Entra ID propagation..."
  sleep 20
fi

# ── Step 3: Assign RBAC role ──────────────────────────────────
section "Step 3 — Assign '${ROLE}' role at subscription scope"

SCOPE="/subscriptions/${SUBSCRIPTION_ID}"

# Check if role already assigned
EXISTING_ROLE=$(az role assignment list \
  --assignee "$APP_ID" \
  --role "$ROLE" \
  --scope "$SCOPE" \
  --query "[0].id" -o tsv 2>/dev/null || true)

if [[ -n "$EXISTING_ROLE" && "$EXISTING_ROLE" != "None" ]]; then
  warn "Role '${ROLE}' already assigned at subscription scope. Skipping."
else
  az role assignment create \
    --assignee "$APP_ID" \
    --role "$ROLE" \
    --scope "$SCOPE" \
    --output none
  success "Role '${ROLE}' assigned at /subscriptions/${SUBSCRIPTION_ID}"
fi

# ── Step 4: Federated credentials ────────────────────────────
section "Step 4 — Create OIDC Federated Credentials"

# Helper function to create a federated credential if it doesn't exist
create_federated_credential() {
  local CRED_NAME="$1"
  local SUBJECT="$2"
  local DESCRIPTION="$3"

  EXISTING=$(az ad app federated-credential list --id "$APP_ID" \
    --query "[?name=='${CRED_NAME}'].id" -o tsv 2>/dev/null || true)

  if [[ -n "$EXISTING" ]]; then
    warn "Federated credential '${CRED_NAME}' already exists. Skipping."
    return
  fi

  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"${CRED_NAME}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"${SUBJECT}\",
    \"description\": \"${DESCRIPTION}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" --output none

  success "Created: ${CRED_NAME}"
  info   "  Subject: ${SUBJECT}"
}

# 1. Push / manual trigger on main branch
create_federated_credential \
  "github-branch-main" \
  "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main" \
  "GitHub Actions — push or workflow_dispatch on main"

# 2. Pull requests (validate + what-if only)
create_federated_credential \
  "github-pull-request" \
  "repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request" \
  "GitHub Actions — pull request runs"

# 3. GitHub Environment: dev
create_federated_credential \
  "github-environment-dev" \
  "repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:dev" \
  "GitHub Actions — deploy to dev environment"

# 4. GitHub Environment: prod
create_federated_credential \
  "github-environment-prod" \
  "repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:prod" \
  "GitHub Actions — deploy to prod environment"

# ── Step 5: Output GitHub secrets ────────────────────────────
section "Step 5 — GitHub Secrets"

echo ""
echo -e "${YELLOW}Add the following three secrets to your GitHub repository:${NC}"
echo -e "${YELLOW}  Settings → Secrets and variables → Actions → New repository secret${NC}"
echo ""
printf "  %-30s %s\n" "Secret Name" "Value"
printf "  %-30s %s\n" "──────────────────────────────" "──────────────────────────────────────"
printf "  %-30s %s\n" "AZURE_CLIENT_ID"       "$APP_ID"
printf "  %-30s %s\n" "AZURE_TENANT_ID"       "$TENANT_ID"
printf "  %-30s %s\n" "AZURE_SUBSCRIPTION_ID" "$SUBSCRIPTION_ID"
echo ""

# ── Optional: set secrets via GitHub CLI ─────────────────────
if command -v gh >/dev/null 2>&1; then
  echo ""
  read -p "GitHub CLI detected. Set secrets automatically? [y/N] " -r
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    gh secret set AZURE_CLIENT_ID       --repo "${GITHUB_ORG}/${GITHUB_REPO}" --body "$APP_ID"
    gh secret set AZURE_TENANT_ID       --repo "${GITHUB_ORG}/${GITHUB_REPO}" --body "$TENANT_ID"
    gh secret set AZURE_SUBSCRIPTION_ID --repo "${GITHUB_ORG}/${GITHUB_REPO}" --body "$SUBSCRIPTION_ID"
    success "GitHub secrets set via GitHub CLI"
  fi
else
  warn "GitHub CLI (gh) not found — set secrets manually using the values above."
  info  "Install: https://cli.github.com"
fi

# ── Step 6: GitHub Environments reminder ─────────────────────
section "Step 6 — GitHub Environments (manual step)"

echo -e "${YELLOW}Create two environments in GitHub:${NC}"
echo "  Settings → Environments → New environment"
echo ""
echo "  1. Name: dev"
echo "     → No required reviewers (auto-deploys on push to main)"
echo ""
echo "  2. Name: prod"
echo "     → Add required reviewers (prevents accidental prod deploys)"
echo ""

# ── Summary ───────────────────────────────────────────────────
section "Summary"

success "Service Principal setup complete!"
echo ""
echo "  App Registration : ${APP_NAME}"
echo "  App (Client) ID  : ${APP_ID}"
echo "  Tenant ID        : ${TENANT_ID}"
echo "  Subscription ID  : ${SUBSCRIPTION_ID}"
echo "  Role             : ${ROLE} @ /subscriptions/${SUBSCRIPTION_ID}"
echo "  Federated creds  : 4 (branch:main, pull_request, env:dev, env:prod)"
echo ""
info "Next: push a change to 'Azure Infrastructure/' to trigger the pipeline."

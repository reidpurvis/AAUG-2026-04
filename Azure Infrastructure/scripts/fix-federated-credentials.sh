#!/usr/bin/env bash
# ==============================================================
# fix-federated-credentials.sh
# Adds the 4 OIDC federated credentials to an existing App
# Registration. Run this if the pipeline fails with AADSTS70025.
#
# Usage:
#   chmod +x fix-federated-credentials.sh
#   ./fix-federated-credentials.sh
# ==============================================================

set -euo pipefail

GITHUB_ORG="reidpurvis"
GITHUB_REPO="AAUG-2026-04"

# ── Find the App Registration ──────────────────────────────────
echo "Looking up App Registration..."
APP_ID=$(az ad app list \
  --display-name "sp-github-aaug-2026-04" \
  --query "[0].appId" -o tsv)

if [[ -z "$APP_ID" || "$APP_ID" == "None" ]]; then
  echo "ERROR: Could not find App Registration 'sp-github-aaug-2026-04'"
  echo "Run setup-service-principal.sh first."
  exit 1
fi

echo "Found App ID: ${APP_ID}"
echo ""

# ── Helper ─────────────────────────────────────────────────────
create_credential() {
  local NAME="$1"
  local SUBJECT="$2"
  local DESC="$3"

  # Check if already exists
  EXISTING=$(az ad app federated-credential list \
    --id "$APP_ID" \
    --query "[?name=='${NAME}'].id" -o tsv 2>/dev/null || true)

  if [[ -n "$EXISTING" ]]; then
    echo "  ⚠  Already exists: ${NAME} — skipping"
    return
  fi

  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"${NAME}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"${SUBJECT}\",
    \"description\": \"${DESC}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" --output none

  echo "  ✅ Created: ${NAME}"
  echo "     Subject: ${SUBJECT}"
}

echo "Creating federated credentials..."
echo ""

create_credential \
  "github-branch-main" \
  "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main" \
  "GitHub Actions — push or workflow_dispatch on main"

create_credential \
  "github-pull-request" \
  "repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request" \
  "GitHub Actions — pull request runs"

create_credential \
  "github-environment-dev" \
  "repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:dev" \
  "GitHub Actions — deploy to dev environment"

create_credential \
  "github-environment-prod" \
  "repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:prod" \
  "GitHub Actions — deploy to prod environment"

echo ""
echo "Verifying — current federated credentials:"
az ad app federated-credential list \
  --id "$APP_ID" \
  --query "[].{Name:name, Subject:subject}" \
  --output table

echo ""
echo "Done. Re-trigger the GitHub Actions pipeline to test."

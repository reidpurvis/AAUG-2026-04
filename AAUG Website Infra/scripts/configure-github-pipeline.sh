#!/bin/bash

# ============================================================
# configure-github-pipeline.sh
# Sets up GitHub Actions secrets for AAUG Website deployment
# ============================================================

set -euo pipefail

# ── Colors ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# ── Configuration ──────────────────────────────────────────
GITHUB_REPO="${1:-}"

# ── Validation ─────────────────────────────────────────────
if [[ -z "$GITHUB_REPO" ]]; then
    log_error "GitHub repository not provided"
    echo ""
    echo "Usage: $0 <github-owner/github-repo>"
    echo "Example: $0 myorg/AAUG-2026-04"
    exit 1
fi

if ! command -v az &> /dev/null; then
    log_error "Azure CLI not found. Please install 'az' CLI."
    exit 1
fi

if ! command -v gh &> /dev/null; then
    log_warning "GitHub CLI not found. You'll need to manually add secrets."
    log_info "Install from: https://cli.github.com/"
    read -p "Continue without GitHub CLI? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    GITHUB_CLI=false
else
    GITHUB_CLI=true
fi

# ── Main Execution ─────────────────────────────────────────
main() {
    log_info "GitHub Actions Pipeline Configuration"
    echo ""

    # Get Azure details
    log_info "Retrieving Azure account details..."
    CLIENT_ID=$(az account list --query "[?state=='Enabled'].id" -o tsv | head -1)
    TENANT_ID=$(az account show --query tenantId -o tsv)
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)

    if [[ -z "$CLIENT_ID" ]] || [[ -z "$TENANT_ID" ]]; then
        log_error "Failed to retrieve Azure details. Run 'az login' first."
        exit 1
    fi

    echo "Azure Account Information:"
    echo "  Subscription ID: $SUBSCRIPTION_ID"
    echo "  Tenant ID: $TENANT_ID"
    echo "  GitHub Repo: $GITHUB_REPO"
    echo ""

    read -p "$(echo -e ${BLUE}?${NC} "Proceed with configuration? (y/N): ")" -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Configuration cancelled"
        exit 0
    fi

    # Configure secrets
    if [[ "$GITHUB_CLI" == "true" ]]; then
        log_info "Adding GitHub secrets using gh CLI..."

        gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID" --repo "$GITHUB_REPO"
        log_success "AZURE_CLIENT_ID configured"

        gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --repo "$GITHUB_REPO"
        log_success "AZURE_TENANT_ID configured"

        gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --repo "$GITHUB_REPO"
        log_success "AZURE_SUBSCRIPTION_ID configured"

        # Create environments
        log_info "Creating GitHub Environments..."

        # Dev environment (no approval)
        gh api repos/"$GITHUB_REPO"/environments/dev -f name=dev -f protection_rules='[]' 2>/dev/null || \
            log_warning "Could not create dev environment (may already exist)"

        # Staging (approval required)
        gh api repos/"$GITHUB_REPO"/environments/staging \
            -f name=staging \
            -f protection_rules='[{"type":"required_reviewers","reviewers":[]}]' 2>/dev/null || \
            log_warning "Could not create staging environment (may already exist)"

        # Prod (approval required)
        gh api repos/"$GITHUB_REPO"/environments/prod \
            -f name=prod \
            -f protection_rules='[{"type":"required_reviewers","reviewers":[]}]' 2>/dev/null || \
            log_warning "Could not create prod environment (may already exist)"

        log_success "GitHub environments configured"
        echo ""
        log_info "Next steps:"
        echo "  1. Visit: https://github.com/$GITHUB_REPO/settings/secrets/actions"
        echo "  2. Verify secrets are configured:"
        echo "     - AZURE_CLIENT_ID"
        echo "     - AZURE_TENANT_ID"
        echo "     - AZURE_SUBSCRIPTION_ID"
        echo ""
        echo "  3. Visit: https://github.com/$GITHUB_REPO/settings/environments"
        echo "  4. For staging & prod environments:"
        echo "     - Add required reviewers"
        echo "     - Restrict to main branch"
        echo ""
        log_success "Configuration complete!"

    else
        log_warning "GitHub CLI not installed. Manual configuration required:"
        echo ""
        echo "1. Visit: https://github.com/$GITHUB_REPO/settings/secrets/actions"
        echo "2. Add these secrets:"
        echo ""
        echo "   Secret Name: AZURE_CLIENT_ID"
        echo "   Value: $CLIENT_ID"
        echo ""
        echo "   Secret Name: AZURE_TENANT_ID"
        echo "   Value: $TENANT_ID"
        echo ""
        echo "   Secret Name: AZURE_SUBSCRIPTION_ID"
        echo "   Value: $SUBSCRIPTION_ID"
        echo ""
        echo "3. Visit: https://github.com/$GITHUB_REPO/settings/environments"
        echo "4. Create environments: dev, staging, prod"
        echo "5. For staging & prod, add required reviewers"
    fi
}

main "$@"

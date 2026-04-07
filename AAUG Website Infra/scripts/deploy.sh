#!/bin/bash

# ============================================================
# deploy.sh — AAUG Website Infrastructure Deployment
# Deploys Azure Static Website infrastructure using Bicep
# ============================================================

set -euo pipefail

# ── Configuration ──────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${1:-dev}"
VERBOSITY="${2:-normal}"

# Define parameter file based on environment
PARAMETERS_FILE="${PROJECT_ROOT}/parameters/parameters.${ENVIRONMENT}.json"
BICEP_FILE="${PROJECT_ROOT}/main.bicep"

# ── Colors for output ──────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ── Logging functions ──────────────────────────────────────
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# ── Validation ─────────────────────────────────────────────
validate_environment() {
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        log_error "Invalid environment: $ENVIRONMENT"
        log_info "Valid environments: dev, staging, prod"
        exit 1
    fi
}

validate_files() {
    if [[ ! -f "$BICEP_FILE" ]]; then
        log_error "Bicep file not found: $BICEP_FILE"
        exit 1
    fi

    if [[ ! -f "$PARAMETERS_FILE" ]]; then
        log_error "Parameters file not found: $PARAMETERS_FILE"
        exit 1
    fi
}

validate_azure_cli() {
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI not found. Please install 'az' CLI."
        exit 1
    fi
}

validate_authentication() {
    if ! az account show > /dev/null 2>&1; then
        log_error "Not authenticated with Azure. Run 'az login' first."
        exit 1
    fi
}

# ── Main Deployment ───────────────────────────────────────
deploy() {
    log_info "Deploying AAUG Website Infrastructure"
    log_info "Environment: $ENVIRONMENT"
    log_info "Bicep file: $BICEP_FILE"
    log_info "Parameters: $PARAMETERS_FILE"
    echo ""

    # Validate subscription and get details
    SUBSCRIPTION=$(az account show --query id -o tsv)
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

    log_info "Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION)"
    echo ""

    # Determine verbosity flag
    VERBOSE_FLAG=""
    if [[ "$VERBOSITY" == "debug" ]]; then
        VERBOSE_FLAG="--debug"
    elif [[ "$VERBOSITY" == "verbose" ]]; then
        VERBOSE_FLAG="--verbose"
    fi

    # Deploy using az cli
    log_info "Starting deployment..."

    az deployment sub create \
        --location australiaeast \
        --template-file "$BICEP_FILE" \
        --parameters "@$PARAMETERS_FILE" \
        $VERBOSE_FLAG

    if [[ $? -eq 0 ]]; then
        log_success "Deployment completed successfully!"

        # Display outputs
        echo ""
        log_info "Deployment outputs:"
        az deployment sub show \
            --name "$(basename "$BICEP_FILE" .bicep)" \
            --query properties.outputs \
            -o table
    else
        log_error "Deployment failed!"
        exit 1
    fi
}

# ── Main Execution ────────────────────────────────────────
main() {
    log_info "AAUG Website Infrastructure Deployment Script"
    echo ""

    validate_environment
    validate_files
    validate_azure_cli
    validate_authentication

    # Confirm deployment
    read -p "$(echo -e ${BLUE}?${NC} "Continue with deployment to $ENVIRONMENT environment? (y/N): ")" -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Deployment cancelled."
        exit 0
    fi

    deploy
}

# ── Entry Point ────────────────────────────────────────────
main "$@"

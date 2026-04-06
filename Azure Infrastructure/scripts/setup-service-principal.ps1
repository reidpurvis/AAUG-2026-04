# ==============================================================
# setup-service-principal.ps1
# Creates an Entra ID App Registration + Service Principal
# with OIDC federated credentials for GitHub Actions.
#
# Usage (from repo root):
#   .\Azure Infrastructure\scripts\setup-service-principal.ps1
#
# Requirements:
#   - Azure CLI (az) installed and logged in
#   - GitHub CLI (gh) installed and authenticated  [optional]
#   - Sufficient permissions: Application Administrator +
#     Owner/User Access Administrator on the subscription
# ==============================================================

#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Config — edit these ───────────────────────────────────────
$AppName    = "sp-github-aaug-2026-04"
$GithubOrg  = "reidpurvis"
$GithubRepo = "AAUG-2026-04"
$Role       = "Contributor"
# ─────────────────────────────────────────────────────────────

function Write-Section ($msg) {
    Write-Host "`n══════════════════════════════════════" -ForegroundColor Blue
    Write-Host " $msg" -ForegroundColor Blue
    Write-Host "══════════════════════════════════════" -ForegroundColor Blue
}
function Write-Info    ($msg) { Write-Host "ℹ  $msg" -ForegroundColor Cyan }
function Write-Success ($msg) { Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Warn    ($msg) { Write-Host "⚠  $msg" -ForegroundColor Yellow }
function Write-Err     ($msg) { Write-Host "❌ $msg" -ForegroundColor Red; exit 1 }

# ── Pre-flight ────────────────────────────────────────────────
Write-Section "Pre-flight checks"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) { Write-Err "Azure CLI not found. Install from https://aka.ms/installazurecli" }
try { az account show *>$null } catch { Write-Err "Not logged in. Run: az login" }

$SubscriptionId   = az account show --query id -o tsv
$SubscriptionName = az account show --query name -o tsv
$TenantId         = az account show --query tenantId -o tsv

Write-Info "Subscription : $SubscriptionName"
Write-Info "Subscription ID : $SubscriptionId"
Write-Info "Tenant ID       : $TenantId"
Write-Info "App name        : $AppName"
Write-Info "GitHub repo     : $GithubOrg/$GithubRepo"

$confirm = Read-Host "`nProceed with these settings? [y/N]"
if ($confirm -notmatch '^[Yy]$') { Write-Host "Aborted."; exit 0 }

# ── Step 1: App Registration ──────────────────────────────────
Write-Section "Step 1 — Create App Registration"

$ExistingAppId = az ad app list --display-name $AppName --query "[0].appId" -o tsv 2>$null

if ($ExistingAppId -and $ExistingAppId -ne "None") {
    Write-Warn "App '$AppName' already exists (App ID: $ExistingAppId). Using existing."
    $AppId = $ExistingAppId
} else {
    $AppId = az ad app create --display-name $AppName --query appId -o tsv
    Write-Success "App Registration created. App ID: $AppId"
}

# ── Step 2: Service Principal ─────────────────────────────────
Write-Section "Step 2 — Create Service Principal"

$ExistingSp = az ad sp list --filter "appId eq '$AppId'" --query "[0].id" -o tsv 2>$null

if ($ExistingSp -and $ExistingSp -ne "None") {
    Write-Warn "Service Principal already exists. Skipping."
    $SpObjectId = $ExistingSp
} else {
    $SpObjectId = az ad sp create --id $AppId --query id -o tsv
    Write-Success "Service Principal created. Object ID: $SpObjectId"
    Write-Info "Waiting 20s for Entra ID propagation..."
    Start-Sleep -Seconds 20
}

# ── Step 3: RBAC Role Assignment ──────────────────────────────
Write-Section "Step 3 — Assign '$Role' at subscription scope"

$Scope = "/subscriptions/$SubscriptionId"
$ExistingRole = az role assignment list --assignee $AppId --role $Role --scope $Scope --query "[0].id" -o tsv 2>$null

if ($ExistingRole -and $ExistingRole -ne "None") {
    Write-Warn "Role '$Role' already assigned. Skipping."
} else {
    az role assignment create --assignee $AppId --role $Role --scope $Scope --output none
    Write-Success "Role '$Role' assigned at /subscriptions/$SubscriptionId"
}

# ── Step 4: Federated Credentials ────────────────────────────
Write-Section "Step 4 — Create OIDC Federated Credentials"

function New-FederatedCredential($Name, $Subject, $Description) {
    $existing = az ad app federated-credential list --id $AppId --query "[?name=='$Name'].id" -o tsv 2>$null
    if ($existing) { Write-Warn "Credential '$Name' already exists. Skipping."; return }

    $params = @{
        name        = $Name
        issuer      = "https://token.actions.githubusercontent.com"
        subject     = $Subject
        description = $Description
        audiences   = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Compress

    az ad app federated-credential create --id $AppId --parameters $params --output none
    Write-Success "Created: $Name"
    Write-Info   "  Subject: $Subject"
}

New-FederatedCredential `
    "github-branch-main" `
    "repo:$GithubOrg/${GithubRepo}:ref:refs/heads/main" `
    "GitHub Actions — push or workflow_dispatch on main"

New-FederatedCredential `
    "github-pull-request" `
    "repo:$GithubOrg/${GithubRepo}:pull_request" `
    "GitHub Actions — pull request runs"

New-FederatedCredential `
    "github-environment-dev" `
    "repo:$GithubOrg/${GithubRepo}:environment:dev" `
    "GitHub Actions — deploy to dev environment"

New-FederatedCredential `
    "github-environment-prod" `
    "repo:$GithubOrg/${GithubRepo}:environment:prod" `
    "GitHub Actions — deploy to prod environment"

# ── Step 5: GitHub Secrets ────────────────────────────────────
Write-Section "Step 5 — GitHub Secrets"

Write-Host ""
Write-Host "Add these secrets to your GitHub repository:" -ForegroundColor Yellow
Write-Host "  Settings → Secrets and variables → Actions → New repository secret" -ForegroundColor Yellow
Write-Host ""
Write-Host ("  {0,-30} {1}" -f "Secret Name", "Value")
Write-Host ("  {0,-30} {1}" -f ("─" * 30), ("─" * 40))
Write-Host ("  {0,-30} {1}" -f "AZURE_CLIENT_ID",       $AppId)
Write-Host ("  {0,-30} {1}" -f "AZURE_TENANT_ID",       $TenantId)
Write-Host ("  {0,-30} {1}" -f "AZURE_SUBSCRIPTION_ID", $SubscriptionId)
Write-Host ""

if (Get-Command gh -ErrorAction SilentlyContinue) {
    $setSecrets = Read-Host "GitHub CLI detected. Set secrets automatically? [y/N]"
    if ($setSecrets -match '^[Yy]$') {
        gh secret set AZURE_CLIENT_ID       --repo "$GithubOrg/$GithubRepo" --body $AppId
        gh secret set AZURE_TENANT_ID       --repo "$GithubOrg/$GithubRepo" --body $TenantId
        gh secret set AZURE_SUBSCRIPTION_ID --repo "$GithubOrg/$GithubRepo" --body $SubscriptionId
        Write-Success "GitHub secrets set via GitHub CLI"
    }
} else {
    Write-Warn "GitHub CLI (gh) not found — set secrets manually. Install: https://cli.github.com"
}

# ── Step 6: GitHub Environments reminder ─────────────────────
Write-Section "Step 6 — GitHub Environments (manual step)"

Write-Host "Create two environments in GitHub:" -ForegroundColor Yellow
Write-Host "  Settings → Environments → New environment"
Write-Host ""
Write-Host "  1. Name: dev"
Write-Host "     → No required reviewers (auto-deploys on push to main)"
Write-Host ""
Write-Host "  2. Name: prod"
Write-Host "     → Add required reviewers (prevents accidental prod deploys)"

# ── Summary ───────────────────────────────────────────────────
Write-Section "Summary"

Write-Success "Service Principal setup complete!"
Write-Host ""
Write-Host "  App Registration : $AppName"
Write-Host "  App (Client) ID  : $AppId"
Write-Host "  Tenant ID        : $TenantId"
Write-Host "  Subscription ID  : $SubscriptionId"
Write-Host "  Role             : $Role @ /subscriptions/$SubscriptionId"
Write-Host "  Federated creds  : 4 (branch:main, pull_request, env:dev, env:prod)"
Write-Host ""
Write-Info "Next: push a change to 'Azure Infrastructure/' to trigger the pipeline."

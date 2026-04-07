# 🚀 AAUG Website Deployment Guide

## Commit Summary

I've created a complete **automated deployment pipeline** to deploy your AAUG Website App to Azure Static Web Apps. Here's what was added:

### Files Created

```
✅ .github/workflows/deploy-aaug-website.yml    GitHub Actions pipeline
✅ AAUG Website App/README.md                   Website documentation
✅ AAUG Website App/DEPLOYMENT.md               Pipeline setup guide
✅ AAUG Website App/setup-github-deployment.sh  Automated setup script
```

**Commit**: `3a5ea50` - Add automated deployment pipeline for AAUG Website

---

## 📋 How It Works

### Pipeline Architecture

```
You push to GitHub
        ↓
GitHub Actions triggered
        ↓
    [1] Authenticate with Azure (Federated Identity)
    [2] Retrieve Static Web App deployment token
    [3] Deploy website files from AAUG Website App/
    [4] Report deployment URL
        ↓
Website is LIVE and accessible
```

### Deployment Triggers

The pipeline automatically deploys when:
- **Push to `main` branch** + changes in `AAUG Website App/` folder
- **Workflow dispatch** (manual trigger) for dev/staging/prod environments

---

## 🎯 Next Steps to Deploy

### Step 1: Set Up Azure Infrastructure

First, deploy the bicep templates from earlier:

```bash
cd AAUG\ Website\ Infra
ENV="dev"
az deployment sub create \
  --name "aaug-website-${ENV}" \
  --location eastus2 \
  --template-file main.bicep \
  --parameters @parameters/parameters.${ENV}.json
```

This creates:
- ✅ Resource Group: `aaug-website-rg`
- ✅ Static Web App: `aaug-website-dev` (Free tier)
- ✅ Storage Account: `stweb...web` (fallback)

### Step 2: Configure GitHub Secrets

Run the automated setup script:

```bash
cd "AAUG Website App"
chmod +x setup-github-deployment.sh
./setup-github-deployment.sh
```

This does:
- ✅ Creates Azure Service Principal
- ✅ Sets up Federated Identity (OIDC)
- ✅ Adds GitHub Secrets automatically

**Manual Alternative** (if script fails):
```bash
# Get your Azure values
az account show --query "{tenant: tenantId, subscription: id}" -o json

# Create service principal
az ad app create --display-name "aaug-website-github-deployment" | jq '.appId'

# Add GitHub Secrets via CLI
gh secret set AZURE_CLIENT_ID --body "<client-id>"
gh secret set AZURE_TENANT_ID --body "<tenant-id>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<subscription-id>"
```

### Step 3: Trigger Deployment

Either:

**A) Push a change to trigger automatically**:
```bash
echo "# Updated website" >> "AAUG Website App/README.md"
git add "AAUG Website App/"
git commit -m "Update website"
git push origin main
```

**B) Manually trigger deployment**:
```bash
gh workflow run deploy-aaug-website.yml \
  --ref main \
  -f environment=dev
```

### Step 4: Watch Deployment

```bash
# View workflow status
gh run list --workflow=deploy-aaug-website.yml

# View live logs
gh run view <run-id> --log
```

Or via GitHub UI:
1. Go to **Actions** tab
2. Click **Deploy AAUG Website to Static Web App**
3. Select the latest run to see detailed logs

---

## 🌐 Accessing Your Website

Once deployed, your website will be available at:

### Environment-Based URLs

| Environment | URL | Status |
|---|---|---|
| **Dev** | `https://aaug-website-dev.azurestaticapps.net` | Auto-deployed from main |
| **Prod** | `https://aaug-website-prod.azurestaticapps.net` | Manual deployment |

### Pages

- **Home**: `/index.html` - April 2026 AAUG Meetup
- **Artemis II**: `/artemis.html` - Space mission details

**Full URLs**:
- Home: `https://aaug-website-dev.azurestaticapps.net/index.html`
- Artemis: `https://aaug-website-dev.azurestaticapps.net/artemis.html`

---

## 🎯 Website Features

### index.html — AAUG April 2026 Event
- Hero section with event title and date
- "Infrastructure is Dead" keynote talk preview
- Full agenda timeline (6:00 PM - 9:00 PM)
- Venue and logistics information
- Artemis II mission highlight
- Sponsor recognition

### artemis.html — Space Mission Details
- Artemis II mission overview
- Crew member profiles
- Mission timeline (current day: Day 7)
- Azure & AI connection to mission
- Live status updates

Both pages feature:
- 🎨 Modern, responsive design
- 📱 Mobile-friendly layouts
- ⚡ Zero JavaScript (pure HTML/CSS)
- 🚀 Instant loading (static files)
- 🔐 Secure HTTPS (automatic)

---

## ✏️ How to Edit the Website

### Make Changes

```bash
# Edit a file
nano "AAUG Website App/index.html"

# Add and commit
git add "AAUG Website App/"
git commit -m "Update event details"

# Push to GitHub
git push origin main
```

**Pipeline automatically deploys within 2 minutes** ✨

### What You Can Edit

- **Text content**: Event times, speaker info, agenda items
- **Links**: Meetup URLs, social media, external resources
- **Styling**: Colors, spacing, fonts (CSS in `<style>` tags)
- **HTML structure**: Add sections, cards, or new pages

### Style Variables

Easy color customization:
```css
:root {
  --navy:   #1A1A2E;
  --teal:   #1C8F94;
  --green:  #259D77;
  --blue:   #008BFE;
}
```

---

## 🔍 Monitoring & Logs

### View Deployment Status

```bash
# List recent deployments
gh run list --workflow=deploy-aaug-website.yml --limit 5

# View specific deployment
gh run view <run-id> --log

# Check artifact details
gh run download <run-id>
```

### Troubleshoot Issues

**If deployment fails**:
1. Check GitHub Actions logs (Settings → Actions)
2. Verify Azure secrets are correct
3. Ensure bicep deployment created Static Web App
4. Check resource group: `az group show -n aaug-website-rg`

**If website shows errors**:
1. Check browser console (F12)
2. Verify files deployed: `az staticwebapp show -g aaug-website-rg -n aaug-website-dev`
3. Check paths in HTML are relative

---

## 📊 Deployment Summary

| Component | Status | Location |
|---|---|---|
| **Infrastructure** | Bicep templates | `AAUG Website Infra/` |
| **Website Code** | HTML + CSS | `AAUG Website App/` |
| **Pipeline** | GitHub Actions | `.github/workflows/` |
| **Deployment** | Static Web Apps | Azure (eastus2) |
| **Documentation** | Complete guides | `DEPLOYMENT.md`, `README.md` |

---

## 🎬 Quick Start Checklist

- [ ] 1. Deploy Azure infrastructure (bicep)
- [ ] 2. Run setup script: `./setup-github-deployment.sh`
- [ ] 3. Verify GitHub Secrets are set
- [ ] 4. Push a change to trigger deployment
- [ ] 5. Watch GitHub Actions logs
- [ ] 6. Access the website URL
- [ ] 7. Share URL with team! 🎉

---

## 📚 Documentation

See these files for detailed information:

- **DEPLOYMENT.md** - Complete pipeline setup and troubleshooting
- **README.md** - Website structure, editing guide, and performance info
- **setup-github-deployment.sh** - Automated configuration script

---

## 🆘 Need Help?

### Check These First
1. GitHub Actions logs: `gh run view <run-id> --log`
2. Azure resources: `az staticwebapp list -g aaug-website-rg`
3. Deployment status: `gh workflow run list`

### Common Issues & Fixes

**"Static Web App not found"**
- ✅ Run bicep deployment: `AAUG Website Infra/deploy.sh`

**"Deployment token unavailable"**
- ✅ Azure secrets may be expired
- ✅ Run setup script again: `./setup-github-deployment.sh`

**"Authentication failed"**
- ✅ Check GitHub Secrets (Settings → Secrets)
- ✅ Verify Azure credentials are correct

**"Website shows 404"**
- ✅ Verify files in `AAUG Website App/`
- ✅ Check paths are relative (no `C://` paths)
- ✅ Ensure `index.html` is at root

---

## 🎉 Success!

Once deployed, you'll have:

✅ Fully automatic website deployment
✅ Secure HTTPS with automatic certificates
✅ Global CDN via Azure Static Web Apps
✅ Free tier (100 GB/month traffic)
✅ GitHub integration for easy updates
✅ Professional event website live in minutes

**Share the URL**: It's ready for your audience! 🚀

---

**Deployment Commit**: `3a5ea50`
**Pipeline File**: `.github/workflows/deploy-aaug-website.yml`
**Infrastructure**: `AAUG Website Infra/` bicep templates
**Website**: `AAUG Website App/` HTML files

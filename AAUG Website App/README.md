# AAUG Website App

Welcome to the Adelaide Azure User Group website! This is the front-end application for our April 2026 meetup event page.

## 📋 Overview

This is a **static HTML website** hosted on **Azure Static Web Apps**. The site is automatically deployed via GitHub Actions whenever changes are pushed to the `main` branch.

**Live URL**: Will be displayed after deployment
- Deployed to: `aaug-website-{dev|staging|prod}.azurestaticapps.net`

## 📁 Files

```
AAUG Website App/
├── index.html              Main event landing page
├── artemis.html            Artemis II space mission details
├── DEPLOYMENT.md           Deployment pipeline documentation
├── setup-github-deployment.sh  Automated setup script
└── README.md               This file
```

## 🎯 Pages

### index.html — April 2026 AAUG Meetup
The main event page featuring:
- **Hero Section**: Event title, date, time, location
- **Logistics Grid**: Venue, time, cost, catering details
- **Featured Talk**: "Infrastructure is Dead — Long Live Infrastructure"
  - Speaker: Reid Purvis (Cloud Paradigm)
  - Theme: Agentic AI transforming cloud infrastructure
- **Tonight's Agenda**: Full timeline of talks, demos, Q&A
- **Artemis II Banner**: Link to mission details page
- **Sponsors**: Microsoft Azure, Cloud Paradigm

### artemis.html — Artemis II Mission
Space exploration meets cloud infrastructure:
- **Mission Overview**: Historic lunar flyby details
- **Crew Section**: Four-astronaut team information
- **Mission Timeline**: Launch → Lunar Flyby → Return Journey
- **Azure Connection**: How cloud & AI support mission-critical systems
- **Live Status**: Current mission day, telemetry, distance records

## 🎨 Design

The website features a **modern, responsive design**:
- **Color Scheme**: Navy, Teal, Green, Blue with light/dark modes
- **Typography**: Segoe UI system font stack
- **Layout**: CSS Grid & Flexbox for responsive behavior
- **Animations**: Pulse effects, gradient text, smooth transitions
- **Mobile Friendly**: Works great on all screen sizes

Built with:
- Pure **HTML5** and **CSS3** (no frameworks required)
- Embedded CSS in `<style>` tags
- No external dependencies
- **Zero JavaScript** for maximum performance

## 🚀 Deployment

### Quick Start

1. **First-time setup**:
   ```bash
   cd "AAUG Website App"
   chmod +x setup-github-deployment.sh
   ./setup-github-deployment.sh
   ```

2. **Make changes to the website**:
   ```bash
   # Edit index.html or artemis.html
   git add "AAUG Website App/"
   git commit -m "Update website content"
   git push origin main
   ```

3. **Watch the deployment**:
   - Go to GitHub → Actions
   - Click "Deploy AAUG Website to Static Web App"
   - View live logs as it deploys

4. **Access your site**:
   - Main: `https://aaug-website-dev.azurestaticapps.net/`
   - Artemis II: `https://aaug-website-dev.azurestaticapps.net/artemis.html`

### Manual Deployment

If the GitHub Actions pipeline fails:

```bash
# Get deployment token
TOKEN=$(az staticwebapp list -g aaug-website-rg \
  --query "[?name=='aaug-website-dev'].repositoryToken" -o tsv)

# Deploy using Static Web Apps CLI
npm install -g @azure/static-web-apps-cli
swa deploy --deployment-token $TOKEN
```

## 📖 How to Edit

### Edit Content
1. Open `index.html` or `artemis.html` in your editor
2. Update text, links, or images
3. Save and commit: `git add`, `git commit`, `git push`
4. Pipeline deploys automatically (~2 minutes)

### Edit Styling
CSS is embedded in `<style>` tags within each HTML file:

```html
<style>
  /* CSS variables for theming */
  :root {
    --teal: #1C8F94;
    --green: #259D77;
    --blue: #008BFE;
    --navy: #1A1A2E;
  }

  /* Class definitions */
  body { font-family: 'Segoe UI', system-ui, sans-serif; }
</style>
```

### Update Links
Links point to internal pages and external resources:
```html
<!-- Internal -->
<a href="index.html">Home</a>
<a href="artemis.html">Artemis II</a>

<!-- External -->
<a href="https://www.meetup.com/" target="_blank">Meetup</a>
<a href="https://cloudparadigm.com.au" target="_blank">Cloud Paradigm</a>
```

## 🔧 Development & Testing

### Local Testing
Open files directly in a browser:
```bash
# macOS
open "AAUG Website App/index.html"

# Linux
xdg-open "AAUG Website App/index.html"

# Windows
start "AAUG Website App/index.html"
```

### Validate HTML
```bash
# Using NPM
npm install -g html-validate
html-validate "AAUG Website App/index.html"

# Using Python
python3 -m http.server --directory "AAUG Website App" 8000
# Then open http://localhost:8000
```

## 📊 Performance

- **Size**: ~45 KB (index.html) + ~50 KB (artemis.html)
- **Load Time**: < 1s (static, no database)
- **Lighthouse Score**: 100/100 (performance, accessibility)
- **Browser Support**: All modern browsers (Chrome, Firefox, Safari, Edge)

## 🌐 Deployment Environments

| Environment | URL | Static Web App | When Deploy |
|---|---|---|---|
| **dev** | `...dev.azurestaticapps.net` | `aaug-website-dev` | Push to `main` |
| **prod** | `...azurestaticapps.net` | `aaug-website-prod` | Manual trigger |

## 🔐 Security

- **HTTPS**: All traffic encrypted (automatic with Static Web Apps)
- **No Secrets**: No API keys, credentials, or sensitive data
- **No Backend**: Static HTML only — no server vulnerabilities
- **No Tracking**: No analytics, cookies, or user data collection
- **CORS**: Strict origin policy (no cross-site requests)

## 📱 Responsive Breakpoints

```css
Mobile:   < 680px  (single column, hidden nav)
Tablet:   680px - 1024px  (2 columns)
Desktop:  > 1024px  (3+ columns, full nav)
```

Test on various devices:
```bash
# Chrome DevTools
F12 → Device Toolbar → Select device
```

## 🎯 SEO & Meta Tags

Key meta tags in `<head>`:
```html
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Adelaide Azure User Group — April 2026</title>
<meta name="description" content="...">
```

## 🚢 Deployment Pipeline

```
Git Push → GitHub Actions → Azure Login → Get Token → Deploy to SWA → Live URL
```

See `DEPLOYMENT.md` for detailed pipeline documentation.

## 🆘 Troubleshooting

**Site not updating after push?**
- Check GitHub Actions status: Actions → Deploy AAUG Website
- Look for error messages in the workflow logs
- Verify files are in `AAUG Website App/` folder
- Confirm paths in HTML are relative (no absolute paths)

**Images not loading?**
- Static Web Apps serves files from the app location root
- Use relative paths: `./image.jpg` or `/image.jpg`
- Avoid absolute URLs to external domains

**Styles not applying?**
- CSS is embedded in `<style>` tags — should load with HTML
- Clear browser cache: Ctrl+Shift+Delete (most browsers)
- Verify CSS syntax (no trailing semicolons missing)

**Deployment token expired?**
- Run setup script again: `./setup-github-deployment.sh`
- Or manually retrieve: `az staticwebapp list -g aaug-website-rg`

## 📚 Resources

- [Azure Static Web Apps Docs](https://docs.microsoft.com/azure/static-web-apps/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [HTML5 Specification](https://html.spec.whatwg.org/)
- [CSS Reference](https://developer.mozilla.org/en-US/docs/Web/CSS)
- [AAUG Meetup](https://www.meetup.com/)
- [CloudParadigm.com.au](https://cloudparadigm.com.au)

## 📝 License

© 2026 Adelaide Azure User Group · Supported by Cloud Paradigm Pty Ltd

For questions or contributions, reach out to the AAUG community on Meetup or LinkedIn.

---

**Last Updated**: April 2026
**Maintained By**: Cloud Paradigm + AAUG Community
**Deployed To**: Azure Static Web Apps (eastus2)

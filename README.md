# ML8 SharePoint Template

Version-controlled provisioning for ML8 SharePoint sites. Each site has its
own configuration file, its own page template, and its own GitHub Actions
workflow. The repository uses PnP PowerShell and GitHub Actions.

## What it provisions

Per site, driven by that site's config file and template:

- Document libraries
- A clean modern homepage built from a named layout template
- Quick links and (for document-hub sites) important-date placeholders
- Quick-launch navigation
- The generated page as the site's home page

The deployment is repeatable. It only replaces the managed page named in the
configuration; it does not delete existing documents or unmanaged libraries.

## Repository layout

```text
config/site.schema.json                     Shared JSON schema for site configs
config/accounting-audit.json                Accounting & Audit site configuration
config/administration.json                  Administration site configuration
templates/document-hub.ps1                  Page layout: intro + quick links + dates + activity
templates/landing-page.ps1                  Page layout: intro + quick links + news/events
scripts/Test-Configuration.ps1              Offline configuration validation
scripts/Deploy-SharePoint.ps1               Idempotent PnP provisioning (dispatches to a template)
scripts/Grant-SitePermission.ps1            One-time per-site permission grant (run locally by an admin)
.github/workflows/validate.yml              Pull-request validation
.github/workflows/deploy-accounting-audit.yml   Deploys config/accounting-audit.json only
.github/workflows/deploy-administration.yml     Deploys config/administration.json only
```

Each site's deploy workflow triggers only on changes to that site's own config
file, its own template, or the shared scripts — editing one site's config
never deploys another site.

## GitHub setup

1. Create a GitHub repository and push this folder to its default branch.
2. Create a GitHub environment named `sharepoint-production`.
3. Add required reviewers to the environment if deployment approval is needed.
4. Add these **environment secrets** (shared across all sites):

   - `ENTRA_CLIENT_ID`: Entra application (client) ID of the deployment app
   - `PNP_CERTIFICATE_BASE64`: Base64-encoded PFX certificate
   - `PNP_CERTIFICATE_PASSWORD`: PFX password

5. Add this **environment variable**:

   - `SHAREPOINT_TENANT`: tenant name, for example `contoso.onmicrosoft.com`

   The target site URL is no longer a repo variable — it lives in each site's
   config file as `siteUrl`.

6. Push to `main` (or use **Actions > Run workflow**, entering `DEPLOY`) to
   deploy a given site.

No credentials or tenant-specific URLs should be committed to this repository.

## Entra application permissions

Use certificate-based app-only authentication with the `Sites.Selected`
permission model: the deployment app can only write to sites it has been
explicitly granted access to, not the whole tenant. This means **every new
site requires a one-time permission grant** before its pipeline can deploy —
see "Adding a new site" below.

## Adding a new site

1. Add a config file under `config/`, following `config/site.schema.json`
   (it must include a `siteUrl` and a `template` — currently `document-hub`
   or `landing-page`; add a new file under `templates/` for a different
   layout).
2. Copy an existing workflow (e.g. `deploy-administration.yml`) to a new
   `.github/workflows/deploy-<site>.yml`, pointing its `paths` filter and
   `ConfigurationPath` at the new config file.
3. **Grant the deployment app permission on the new site** — this is a
   manual step performed once by an admin, outside of CI, because it
   requires interactive/delegated admin sign-in:

   ```powershell
   pwsh ./scripts/Grant-SitePermission.ps1 `
     -SiteUrl "https://tenant.sharepoint.com/sites/NewSite" `
     -AdminAppId "<client ID of a temporary admin app with SharePoint AllSites.FullControl>" `
     -DeploymentAppId "<ENTRA_CLIENT_ID value>" `
     -DeploymentAppDisplayName "GitHub SharePoint Deployment"
   ```

   The script signs in interactively, grants `FullControl` to the deployment
   app on that one site, and verifies the grant. Skipping this step causes
   the deploy job to fail at the first `New-PnPList` call with "Attempted to
   perform an unauthorized operation."
4. Run `./scripts/Test-Configuration.ps1 -ConfigurationPath ./config/<new>.json`
   locally, then open a PR.

## Local validation

```powershell
pwsh ./scripts/Test-Configuration.ps1 \
  -ConfigurationPath ./config/accounting-audit.json
```

## Local deployment

Interactive authentication is supported for development:

```powershell
pwsh ./scripts/Deploy-SharePoint.ps1 \
  -ConfigurationPath ./config/accounting-audit.json \
  -SiteUrl "https://tenant.sharepoint.com/sites/AccountingAudit" \
  -ClientId "00000000-0000-0000-0000-000000000000"
```

The account must have permission to modify the target site.

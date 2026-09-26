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

## One-time tenant setup

These steps are only needed once per tenant, before the first site is ever
deployed (or if the temporary admin app described below gets removed).

### 1. Create the deployment app

This is the app the GitHub Actions pipeline authenticates as (its client ID
is the `ENTRA_CLIENT_ID` secret). It uses certificate-based, app-only auth
with the `Sites.Selected` Graph **application** permission — deliberately
narrow, since `Sites.Selected` grants nothing on its own until a site is
individually opted in (see "Adding a new site" below).

If you already have a certificate (`.pfx`) from a previous tenant, you can
reuse it here — a certificate's public key can be uploaded to app
registrations in any number of tenants:

```powershell
Register-PnPEntraIDApp `
  -ApplicationName "GitHub SharePoint Deployment" `
  -Tenant "<tenant>.onmicrosoft.com" `
  -CertificatePath "/path/to/github-sharepoint.pfx" `
  -CertificatePassword (ConvertTo-SecureString -String "<pfx password>" -AsPlainText -Force) `
  -GraphApplicationPermissions "Sites.Selected"
```

Omit `-CertificatePath`/`-CertificatePassword` (and add `-Store CurrentUser`
if on Windows) to have it generate a brand-new self-signed certificate
instead. Either way, this prompts a browser sign-in to grant admin consent,
then prints the new app's client ID — that's the new `ENTRA_CLIENT_ID`.

### 2. Create the temporary admin app used to grant site permissions

`Grant-SitePermission.ps1` needs to sign in interactively as *some* Entra
app to call `Grant-PnPEntraIDAppSitePermission`. Create a throwaway app for
that purpose with PnP's own helper cmdlet:

```powershell
Register-PnPEntraIDAppForInteractiveLogin `
  -ApplicationName "PnP Site Permission Admin" `
  -Tenant "<tenant>.onmicrosoft.com" `
  -GraphDelegatePermissions "Sites.FullControl.All"
```

If it's already registered, this cmdlet fails with "The application with
name PnP Site Permission Admin already exists" — that's expected on a
second run, not an error to fix. Note the app's client ID; that's the
`-AdminAppId` used everywhere below.

**This app needs a SharePoint delegated permission too, not just Graph.**
`Register-PnPEntraIDAppForInteractiveLogin` above only grants a Microsoft
Graph permission. Signing in with just that produces:

```
AADSTS650057: Invalid resource. The client has requested access to a
resource which is not listed in the requested permissions in the client's
application registration.
```

Fix it in the Entra admin center, on that app's **API permissions** page:

1. **Add a permission → APIs my organization uses → SharePoint → Delegated
   permissions → AllSites → AllSites.FullControl → Add permissions.**
2. **Grant admin consent** for the tenant.
3. Confirm both permissions show **Granted**: Microsoft Graph →
   `Sites.FullControl.All`, and SharePoint → `AllSites.FullControl`.

Once both are granted, `Connect-PnPOnline -Url <site> -Interactive -ClientId
<AdminAppId> -ForceAuthentication` succeeds (use `-ForceAuthentication` and
`Disconnect-PnPOnline -ClearPersistedLogin` first if a prior failed sign-in
got cached).

### 3. Encode the deployment certificate for the `PNP_CERTIFICATE_BASE64` secret

If you reused an existing certificate in step 1 and its base64/password are
already sitting in the GitHub environment secrets from a prior tenant, this
step is done — the same secret values still work. Otherwise, base64-encode
the `.pfx` for the GitHub secret:

```powershell
$pfxPath = "/path/to/github-sharepoint.pfx"
$certificateBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($pfxPath))
$certificateBase64 | pbcopy   # copies it to the clipboard (macOS)
```

Paste the clipboard contents directly into the `PNP_CERTIFICATE_BASE64`
environment secret (see "GitHub setup" above) — never commit the `.pfx`,
its base64 form, or its password to the repository.

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
   requires interactive/delegated admin sign-in (see "One-time tenant
   setup" above if the admin app isn't created yet):

   ```powershell
   pwsh ./scripts/Grant-SitePermission.ps1 `
     -SiteUrl "https://tenant.sharepoint.com/sites/NewSite" `
     -AdminAppId "<client ID of the 'PnP Site Permission Admin' app>" `
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

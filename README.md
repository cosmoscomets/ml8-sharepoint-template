# ML8 SharePoint Template

Version-controlled provisioning for the ML8 Accounting & Audit SharePoint site.
The repository uses PnP PowerShell and GitHub Actions.

## What it provisions

- Three document libraries
- A clean modern Accounting & Audit homepage
- Quick links and important-date placeholders
- Quick-launch navigation
- The generated page as the site's home page

The deployment is repeatable. It only replaces the managed page named in the
configuration; it does not delete existing documents or unmanaged libraries.

## Repository layout

```text
config/accounting-audit.json       Site-specific configuration
scripts/Test-Configuration.ps1     Offline configuration validation
scripts/Deploy-SharePoint.ps1      Idempotent PnP provisioning
.github/workflows/validate.yml     Pull-request validation
.github/workflows/deploy.yml       Manual deployment
```

## GitHub setup

1. Create a GitHub repository and push this folder to its default branch.
2. Create a GitHub environment named `sharepoint-production`.
3. Add required reviewers to the environment if deployment approval is needed.
4. Add these **environment secrets**:

   - `ENTRA_CLIENT_ID`: Entra application (client) ID
   - `PNP_CERTIFICATE_BASE64`: Base64-encoded PFX certificate
   - `PNP_CERTIFICATE_PASSWORD`: PFX password

5. Add these **environment variables**:

   - `SHAREPOINT_TENANT`: tenant name, for example `contoso.onmicrosoft.com`
   - `SHAREPOINT_SITE_URL`: full target site URL

6. Open **Actions > Deploy SharePoint template > Run workflow**. Enter `DEPLOY`
   when prompted.

No credentials or tenant-specific URLs should be committed to this repository.

## Entra application permissions

Use certificate-based app-only authentication. Grant the application the least
privilege appropriate for the target site. `Sites.Selected` is preferred; the
application must also receive write permission on the target site. An existing
tenant-wide SharePoint automation identity can be used if your organisation
already operates one.

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

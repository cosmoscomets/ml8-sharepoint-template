[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string] $SiteUrl,

    [Parameter(Mandatory)]
    [string] $AdminAppId,

    [Parameter(Mandatory)]
    [string] $DeploymentAppId,

    [Parameter(Mandatory)]
    [string] $DeploymentAppDisplayName
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module PnP.PowerShell -ErrorAction Stop

Write-Host "Signing in interactively to grant a site-scoped permission on $SiteUrl."
Write-Host "This requires an account with permission to manage site collection access."

Disconnect-PnPOnline -ClearPersistedLogin -ErrorAction SilentlyContinue

try {
    Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $AdminAppId -ForceAuthentication

    Write-Host "Granting '$DeploymentAppDisplayName' ($DeploymentAppId) FullControl on $SiteUrl..."
    Grant-PnPEntraIDAppSitePermission `
        -AppId $DeploymentAppId `
        -DisplayName $DeploymentAppDisplayName `
        -Permissions FullControl `
        -Site $SiteUrl | Out-Null

    $grant = Get-PnPEntraIDAppSitePermission -AppIdentity $DeploymentAppId -Site $SiteUrl
    if (-not $grant) {
        throw "Verification failed: no site permission entry found for app '$DeploymentAppId' on $SiteUrl."
    }

    Write-Host "Verified. Current grant on $SiteUrl :"
    $grant | Format-List
}
finally {
    Disconnect-PnPOnline -ErrorAction SilentlyContinue
}
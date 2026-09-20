[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $ConfigurationPath,

    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string] $SiteUrl,

    [Parameter(Mandatory)]
    [string] $ClientId,

    [string] $Tenant,
    [string] $CertificateBase64,
    [Security.SecureString] $CertificatePassword
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

& "$PSScriptRoot/Test-Configuration.ps1" -ConfigurationPath $ConfigurationPath
$configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json

Import-Module PnP.PowerShell -ErrorAction Stop

if ($CertificateBase64) {
    if (-not $Tenant -or -not $CertificatePassword) {
        throw 'Tenant and CertificatePassword are required for certificate authentication.'
    }

    Connect-PnPOnline `
        -Url $SiteUrl `
        -ClientId $ClientId `
        -Tenant $Tenant `
        -CertificateBase64Encoded $CertificateBase64 `
        -CertificatePassword $CertificatePassword
}
else {
    Connect-PnPOnline -Url $SiteUrl -ClientId $ClientId -Interactive
}

try {
    Write-Host "Provisioning $($configuration.siteTitle) at $SiteUrl"

    foreach ($libraryConfiguration in $configuration.libraries) {
        $library = Get-PnPList -Identity $libraryConfiguration.title -ErrorAction SilentlyContinue
        if (-not $library) {
            Write-Host "Creating library: $($libraryConfiguration.title)"
            New-PnPList `
                -Title $libraryConfiguration.title `
                -Url $libraryConfiguration.url `
                -Template DocumentLibrary `
                -OnQuickLaunch | Out-Null
        }
        else {
            Write-Host "Library already exists: $($libraryConfiguration.title)"
        }
    }

    $pageName = $configuration.page.name
    $pageFileName = "$pageName.aspx"
    $existingPage = Get-PnPPage -Identity $pageFileName -ErrorAction SilentlyContinue
    if ($existingPage) {
        Write-Host "Replacing managed page: $pageFileName"
        Remove-PnPPage -Identity $pageFileName -Force
    }

    $page = Add-PnPPage `
        -Name $pageName `
        -Title $configuration.page.title `
        -LayoutType Home `
        -HeaderLayoutType ColorBlock

    $templateScript = Join-Path $PSScriptRoot "../templates/$($configuration.template).ps1"
    if (-not (Test-Path -LiteralPath $templateScript -PathType Leaf)) {
        throw "Unknown page template '$($configuration.template)'. Expected a script at $templateScript."
    }

    Write-Host "Applying page template: $($configuration.template)"
    & $templateScript -Page $page -Configuration $configuration -SiteUrl $SiteUrl

    Set-PnPPage -Identity $pageFileName -Publish
    Set-PnPHomePage -RootFolderRelativeUrl "SitePages/$pageFileName"

    Write-Host "Deployment completed. Home page: SitePages/$pageFileName"
}
finally {
    Disconnect-PnPOnline
}

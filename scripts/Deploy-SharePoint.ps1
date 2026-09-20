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
        -HeaderLayoutType NoImage

    Add-PnPPageSection -Page $page -SectionTemplate OneColumn -Order 1 -ZoneEmphasis 2

    $introHtml = @"
<h1>$($configuration.page.title)</h1>
<p>$($configuration.page.description)</p>
"@
    Add-PnPPageTextPart -Page $page -Section 1 -Column 1 -Order 1 -Text $introHtml

    Add-PnPPageSection -Page $page -SectionTemplate TwoColumnLeft -Order 2

    $quickLinkItems = foreach ($quickLink in $configuration.quickLinks) {
        $siteBaseUrl = "$($SiteUrl.TrimEnd('/'))/"
        $absoluteUrl = [System.Uri]::new([System.Uri]$siteBaseUrl, $quickLink.url).AbsoluteUri
        "<li><a href='$absoluteUrl'>$($quickLink.label)</a></li>"
    }
    $quickLinksHtml = "<h2>Quick links</h2><ul>$($quickLinkItems -join '')</ul>"
    Add-PnPPageTextPart -Page $page -Section 2 -Column 1 -Order 1 -Text $quickLinksHtml

    $dateItems = foreach ($date in $configuration.importantDates) {
        "<li>$date</li>"
    }
    $datesHtml = "<h2>Important dates</h2><ul>$($dateItems -join '')</ul>"
    Add-PnPPageTextPart -Page $page -Section 2 -Column 2 -Order 1 -Text $datesHtml

    Add-PnPPageSection -Page $page -SectionTemplate OneColumn -Order 3
    Add-PnPPageWebPart `
        -Page $page `
        -DefaultWebPartType SiteActivity `
        -Section 3 `
        -Column 1 `
        -Order 1

    Set-PnPPage -Identity $pageFileName -Publish
    Set-PnPHomePage -RootFolderRelativeUrl "SitePages/$pageFileName"

    Write-Host "Deployment completed. Home page: SitePages/$pageFileName"
}
finally {
    Disconnect-PnPOnline
}

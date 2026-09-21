[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $ConfigurationPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$configuration = Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json

$requiredRootProperties = @('siteTitle', 'siteUrl', 'template', 'page', 'libraries', 'quickLinks', 'importantDates')
foreach ($property in $requiredRootProperties) {
    if ($null -eq $configuration.$property) {
        throw "Configuration is missing required property '$property'."
    }
}

if ([string]::IsNullOrWhiteSpace($configuration.siteTitle)) {
    throw 'siteTitle cannot be empty.'
}

if ($configuration.siteUrl -notmatch '^https://') {
    throw 'siteUrl must be an https URL.'
}

$templateScript = Join-Path $PSScriptRoot "../templates/$($configuration.template).ps1"
if (-not (Test-Path -LiteralPath $templateScript -PathType Leaf)) {
    throw "Unknown page template '$($configuration.template)'. Expected a script at $templateScript."
}

if ($configuration.page.name -notmatch '^[A-Za-z0-9-]+$') {
    throw 'page.name may contain only letters, numbers and hyphens.'
}

if ($configuration.libraries.Count -lt 1) {
    throw 'At least one document library is required.'
}

$duplicateTitles = $configuration.libraries |
    Group-Object -Property title |
    Where-Object Count -gt 1

if ($duplicateTitles) {
    throw "Duplicate library title: $($duplicateTitles.Name -join ', ')."
}

foreach ($library in $configuration.libraries) {
    if ([string]::IsNullOrWhiteSpace($library.title) -or
        $library.url -notmatch '^[A-Za-z0-9-]+$') {
        throw "Invalid document library definition: $($library | ConvertTo-Json -Compress)."
    }
}

function Test-PnPImageAssetExists {
    param([Parameter(Mandatory)] [string] $RelativePath)

    $localPath = Join-Path $PSScriptRoot ".." $RelativePath
    if (-not (Test-Path -LiteralPath $localPath -PathType Leaf)) {
        throw "Image asset not found: $localPath"
    }
}

if ($configuration.PSObject.Properties['heroImage'] -and $configuration.heroImage) {
    Test-PnPImageAssetExists -RelativePath $configuration.heroImage.file
}

if ($configuration.PSObject.Properties['accentColor'] -and $configuration.accentColor -and
    $configuration.accentColor -notmatch '^#[0-9A-Fa-f]{6}$') {
    throw 'accentColor must be a 6-digit hex color, e.g. #5C2D91.'
}

Write-Host "Configuration '$ConfigurationPath' is valid."

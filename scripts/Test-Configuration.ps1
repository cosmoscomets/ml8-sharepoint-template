[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $ConfigurationPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$json = Get-Content -LiteralPath $ConfigurationPath -Raw
$schemaPath = Join-Path $PSScriptRoot '../config/site.schema.json'
if (-not (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction Stop)) {
    throw "Configuration '$ConfigurationPath' does not match site.schema.json."
}
$configuration = $json | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($configuration.siteTitle)) {
    throw 'siteTitle cannot be empty.'
}

$siteUri = $null
if (-not [Uri]::TryCreate($configuration.siteUrl, [UriKind]::Absolute, [ref]$siteUri) -or
    $siteUri.Scheme -ne 'https' -or -not $siteUri.Host -or
    $siteUri.UserInfo -or $siteUri.Query -or $siteUri.Fragment) {
    throw 'siteUrl must be an absolute https URL without credentials, a query or a fragment.'
}

$templateScript = Join-Path $PSScriptRoot "../templates/$($configuration.template).ps1"
if (-not (Test-Path -LiteralPath $templateScript -PathType Leaf)) {
    throw "Unknown page template '$($configuration.template)'. Expected a script at $templateScript."
}

foreach ($property in @('title', 'url')) {
    $duplicates = $configuration.libraries |
        Group-Object -Property $property |
        Where-Object Count -gt 1
    if ($duplicates) {
        throw "Duplicate library ${property}: $($duplicates.Name -join ', ')."
    }
}

foreach ($library in $configuration.libraries) {
    if ([string]::IsNullOrWhiteSpace($library.title)) {
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

Write-Host "Configuration '$ConfigurationPath' is valid."

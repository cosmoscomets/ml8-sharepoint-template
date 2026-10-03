# Offline regression checks; no PnP module or tenant credentials required.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path $PSScriptRoot -Parent
$validator = Join-Path $repositoryRoot 'scripts/Test-Configuration.ps1'
$configDirectory = Join-Path $repositoryRoot 'config'
foreach ($file in Get-ChildItem -LiteralPath $configDirectory -Filter '*.json' -Exclude 'site.schema.json') {
    & $validator -ConfigurationPath $file.FullName
}

$baseline = Get-Content -LiteralPath (Join-Path $configDirectory 'accounting-audit.json') -Raw
$cases = @(
    @{ Name = 'missing root property'; Change = { param($config) $config.Remove('siteTitle') }; Expected = 'schema' }
    @{ Name = 'missing nested property'; Change = { param($config) $config.page.Remove('title') }; Expected = 'schema' }
    @{ Name = 'unknown property'; Change = { param($config) $config['typo'] = 'value' }; Expected = 'schema' }
    @{ Name = 'wrong collection type'; Change = { param($config) $config.quickLinks = 'Documents' }; Expected = 'schema' }
    @{ Name = 'invalid quick link'; Change = { param($config) $config.quickLinks = @(@{ label = 'Documents' }) }; Expected = 'schema' }
    @{ Name = 'invalid date'; Change = { param($config) $config.importantDates = @(42) }; Expected = 'schema' }
    @{ Name = 'invalid CTA'; Change = { param($config) $config.heroCta = @{ label = 'Open' } }; Expected = 'schema' }
    @{ Name = 'invalid color'; Change = { param($config) $config.accentColor = 'red' }; Expected = 'schema' }
    @{ Name = 'invalid summary'; Change = { param($config) $config.page.summary = 42 }; Expected = 'schema' }
    @{ Name = 'template traversal'; Change = { param($config) $config.template = '../scripts/Deploy-SharePoint' }; Expected = 'schema' }
    @{ Name = 'empty libraries'; Change = { param($config) $config.libraries = @() }; Expected = 'schema' }
    @{ Name = 'duplicate titles'; Change = { param($config) $config.libraries[1].title = $config.libraries[0].title.ToUpperInvariant() }; Expected = 'Duplicate library title' }
    @{ Name = 'duplicate URLs'; Change = { param($config) $config.libraries[1].url = $config.libraries[0].url.ToLowerInvariant() }; Expected = 'Duplicate library url' }
    @{ Name = 'blank title'; Change = { param($config) $config.siteTitle = ' ' }; Expected = 'siteTitle cannot be empty' }
    @{ Name = 'incomplete URL'; Change = { param($config) $config.siteUrl = 'https://' }; Expected = 'siteUrl must be' }
    @{ Name = 'URL with credentials'; Change = { param($config) $config.siteUrl = 'https://user:password@example.com/sites/test' }; Expected = 'siteUrl must be' }
    @{ Name = 'URL with query'; Change = { param($config) $config.siteUrl = 'https://example.com/sites/test?query=1' }; Expected = 'siteUrl must be' }
    @{ Name = 'missing image'; Change = { param($config) $config.heroImage.file = 'assets/missing-regression-image.jpg' }; Expected = 'Image asset not found' }
)

$temporaryFile = [IO.Path]::GetTempFileName()
try {
    foreach ($case in $cases) {
        $config = $baseline | ConvertFrom-Json -AsHashtable
        & $case.Change $config
        $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $temporaryFile
        $failure = $null
        try {
            & $validator -ConfigurationPath $temporaryFile
        }
        catch {
            $failure = $_.ToString()
        }
        if (-not $failure -or $failure -notmatch $case.Expected) {
            throw "Case '$($case.Name)' expected '$($case.Expected)', received '$failure'."
        }
    }

    # Optional fields may be omitted, and both link/date collections may be empty.
    $config = $baseline | ConvertFrom-Json -AsHashtable
    foreach ($property in @('heroImage', 'heroCta', 'accentColor')) {
        $config.Remove($property)
    }
    $config.quickLinks = @()
    $config.importantDates = @()
    $config.page.Remove('summary')
    $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $temporaryFile
    & $validator -ConfigurationPath $temporaryFile
}
finally {
    Remove-Item -LiteralPath $temporaryFile
}

Write-Host "All configurations and $($cases.Count) rejection cases passed."

# Offline checks: record PnP calls without importing PnP or connecting to a tenant.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/../scripts/SiteBranding.ps1"

$branding = Get-MoonlightBranding
$script:calls = [Collections.Generic.List[object]]::new()
$script:nodes = [Collections.Generic.List[object]]::new()
function Invoke-PnPSPRestMethod {
    param($Method, $Url, $Content, $ContentType)
    $script:calls.Add(@{ Kind = 'Theme'; Options = @{} + $PSBoundParameters })
}
function Publish-PnPImageAsset {
    param($RelativePath)
    if ($RelativePath -ne $branding.logo) { throw 'Wrong logo asset.' }
    return '/sites/Finance/SiteAssets/moonlight-resources-logo.png'
}
function Set-PnPWebHeader {
    param($SiteLogoUrl, $HeaderLayout, $HeaderEmphasis, [switch] $HideTitleInHeader)
    $script:calls.Add(@{ Kind = 'Header'; Options = @{} + $PSBoundParameters })
}
function Set-PnPWeb {
    param($Title, [switch] $QuickLaunchEnabled, [switch] $HorizontalQuickLaunch)
    $script:calls.Add(@{ Kind = 'Web'; Options = @{} + $PSBoundParameters })
}
function Get-PnPNavigationNode {
    param($Location)
    if ($Location -ne 'QuickLaunch') { throw 'Wrong navigation location.' }
    return $script:nodes.ToArray()
}
function Add-PnPNavigationNode {
    param($Location, $Title, $Url, [switch] $First)
    $node = [pscustomobject]@{ Title = $Title; Url = $Url }
    if ($First) { $script:nodes.Insert(0, $node) } else { $script:nodes.Add($node) }
}
function Invoke-PnPQuery { }

$configs = @(Get-ChildItem -LiteralPath "$PSScriptRoot/../config" -Filter '*.json' -Exclude 'site.schema.json')
if (-not $configs.Count) { throw 'No site configurations found.' }
foreach ($file in $configs) {
    $config = Get-Content $file.FullName -Raw | ConvertFrom-Json
    $script:calls.Clear()
    Set-MoonlightBranding -Configuration $config -SiteUrl $config.siteUrl -Branding $branding
    $theme = $calls[0].Options
    $payload = $theme.Content | ConvertFrom-Json
    $palette = ($payload.themeJson | ConvertFrom-Json).palette
    if ($theme.Method -ne 'Post' -or $theme.Url -ne "$($config.siteUrl)/_api/thememanager/ApplyTheme" -or
        $palette.themePrimary -ne '#153E64' -or $palette.accent -ne '#D4E09B' -or
        $config.accentColor -ne $palette.themePrimary) { throw 'Theme or heading colors do not match the website.' }
    $header = $calls[1].Options
    if ($header.HeaderLayout -ne 'Compact' -or $header.HeaderEmphasis -ne 'None' -or
        $header.HideTitleInHeader -or -not $header.SiteLogoUrl.EndsWith('moonlight-resources-logo.png')) {
        throw 'Header must show the logo and department title on a light background.'
    }
    $web = $calls[2].Options
    if ($web.Title -ne $config.siteTitle -or -not $web.QuickLaunchEnabled -or -not $web.HorizontalQuickLaunch) {
        throw 'Department title or horizontal navigation missing.'
    }

    $script:nodes.Clear()
    $script:nodes.Add([pscustomobject]@{ Title = 'Existing link'; Url = 'https://example.com/manual' })
    # Existing libraries may be returned using a server-relative URL.
    $relativeUrl = ([Uri]$config.siteUrl).AbsolutePath + '/' + $config.quickLinks[0].url
    $script:nodes.Add([pscustomobject]@{ Title = $config.quickLinks[0].label; Url = $relativeUrl })
    Sync-MoonlightNavigation -Configuration $config -SiteUrl $config.siteUrl
    Sync-MoonlightNavigation -Configuration $config -SiteUrl "$($config.siteUrl)/"
    if ($nodes.Count -ne $config.quickLinks.Count + 2 -or $nodes[0].Title -ne 'Home' -or
        @($nodes | Where-Object Title -eq 'Existing link').Count -ne 1) { throw 'Navigation is not additive and repeatable.' }
    $config.quickLinks = @()
    $script:nodes.Clear()
    Sync-MoonlightNavigation -Configuration $config -SiteUrl 'https://example.com'
    if ($nodes.Count -ne 1 -or $nodes[0].Url -ne "https://example.com/SitePages/$($config.page.name).aspx") {
        throw 'Empty links or root site navigation failed.'
    }
    $script:nodes.Clear()
    $homeNode = [pscustomobject]@{ Title = 'Home'; Url = $config.siteUrl }
    $homeNode | Add-Member -MemberType ScriptMethod -Name Update -Value { }
    $script:nodes.Add($homeNode)
    Sync-MoonlightNavigation -Configuration $config -SiteUrl $config.siteUrl
    if ($nodes.Count -ne 1 -or $nodes[0].Url -ne "$($config.siteUrl)/SitePages/$($config.page.name).aspx") {
        throw 'Existing Home navigation was duplicated instead of updated.'
    }
}
Write-Host "Branding and repeat-deployment navigation passed for $($configs.Count) sites."

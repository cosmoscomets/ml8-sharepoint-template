function Get-MoonlightBranding {
    $branding = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../branding/moonlight.json') -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($branding.name) -or $branding.theme.isInverted -ne $false) {
        throw 'Moonlight branding requires a name and a light theme.'
    }
    foreach ($slot in @('themePrimary', 'themeDarker', 'neutralPrimary', 'white', 'accent')) {
        if (-not $branding.theme.palette.PSObject.Properties[$slot]) { throw "Missing theme slot: $slot" }
    }
    foreach ($color in $branding.theme.palette.PSObject.Properties) {
        if ($color.Value -notmatch '^#[0-9A-Fa-f]{6}$') { throw "Invalid theme color: $($color.Name)" }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot '..' $branding.logo) -PathType Leaf)) {
        throw "Brand logo not found: $($branding.logo)"
    }
    return $branding
}

function Set-MoonlightBranding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Configuration,
        [Parameter(Mandatory)] [string] $SiteUrl,
        [Parameter(Mandatory)] $Branding
    )

    # Apply directly to the connected site; do not register or change tenant themes.
    # https://learn.microsoft.com/sharepoint/dev/declarative-customization/site-theming/sharepoint-site-theming-rest-api#applytheme
    $body = @{
        name = $Branding.name
        themeJson = ($Branding.theme | ConvertTo-Json -Depth 10 -Compress)
    } | ConvertTo-Json -Compress
    Invoke-PnPSPRestMethod -Method Post -Url "$($SiteUrl.TrimEnd('/'))/_api/thememanager/ApplyTheme" `
        -Content $body -ContentType 'application/json; charset=utf-8' | Out-Null

    $logo = Publish-PnPImageAsset -RelativePath $Branding.logo
    Set-PnPWebHeader -SiteLogoUrl $logo -HeaderLayout Compact -HeaderEmphasis None -HideTitleInHeader:$false | Out-Null
    Set-PnPWeb -Title $Configuration.siteTitle -QuickLaunchEnabled:$true -HorizontalQuickLaunch:$true | Out-Null
}

function Sync-MoonlightNavigation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Configuration,
        [Parameter(Mandatory)] [string] $SiteUrl
    )

    $baseUri = [Uri]"$($SiteUrl.TrimEnd('/'))/"
    $existingNodes = @(Get-PnPNavigationNode -Location QuickLaunch)
    $homeNode = $existingNodes | Where-Object Title -eq 'Home' | Select-Object -First 1
    $existingUrls = @($existingNodes | ForEach-Object {
        if ($_.Url) { [Uri]::new($baseUri, $_.Url).AbsoluteUri.TrimEnd('/') }
    })
    $links = @([pscustomobject]@{ label = 'Home'; url = "SitePages/$($Configuration.page.name).aspx" }) + @($Configuration.quickLinks)
    for ($index = 0; $index -lt $links.Count; $index++) {
        $link = $links[$index]
        $url = [Uri]::new($baseUri, $link.url).AbsoluteUri
        if ($url.TrimEnd('/') -notin $existingUrls) {
            if ($index -eq 0 -and $homeNode) {
                $homeNode.Url = $url
                $homeNode.Update()
                Invoke-PnPQuery
            }
            else {
                Add-PnPNavigationNode -Location QuickLaunch -Title $link.label -Url $url -First:($index -eq 0) | Out-Null
            }
            $existingUrls += $url.TrimEnd('/')
        }
    }
}

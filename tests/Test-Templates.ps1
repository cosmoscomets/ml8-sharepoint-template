[CmdletBinding()]
param([string] $CapturePath)

# Capture the real template output without connecting to SharePoint.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repositoryRoot = Split-Path $PSScriptRoot -Parent

function Add-PnPPageSection {
    param($Page, $SectionTemplate, $Order, $ZoneEmphasis)
    $options = @{} + $PSBoundParameters
    $options.Remove('Page')
    $Page.Sections.Add($options)
}
function Add-PnPPageTextPart {
    param($Page, $Section, $Column, $Order, $Text)
    $options = @{} + $PSBoundParameters
    $options.Remove('Page')
    $Page.Controls.Add(@{ Kind = 'Text'; Options = $options })
}
function Add-PnPPageImageWebPart {
    param($Page, $Section, $Column, $Order, $ImageUrl, $AlternativeText, $ImageWidth, $ImageHeight)
    $options = @{} + $PSBoundParameters
    $options.Remove('Page')
    $Page.Controls.Add(@{ Kind = 'Image'; Options = $options })
}
function Add-PnPPageWebPart {
    param($Page, $Section, $Column, $Order, $DefaultWebPartType, $WebPartProperties)
    $options = @{} + $PSBoundParameters
    $options.Remove('Page')
    $Page.Controls.Add(@{ Kind = $DefaultWebPartType; Options = $options })
}

$captures = @(foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'config') -Filter '*.json' -Exclude 'site.schema.json') {
    foreach ($variant in @('configured', 'minimal', 'single-link')) {
        $config = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $imageUrl = $config.heroImage.file
        $imageAlt = $config.heroImage.alt
        $listId = '11111111-1111-1111-1111-111111111111'
        if ($variant -eq 'minimal') {
            $config.page.PSObject.Properties.Remove('summary')
            $config.page.description = ''
            $config.PSObject.Properties.Remove('heroCta')
            $config.quickLinks = @()
            $config.importantDates = @()
            $imageUrl = $null
            $listId = $null
        }
        if ($variant -eq 'single-link') {
            $config.quickLinks = @($config.quickLinks[0])
            $config.page.title = 'A & B <C>'
            $config.page.summary = 'Text <script>alert(1)</script>'
            $config.page.description = 'Details <em>as text</em>'
            $config.importantDates = @('<em>Reminder</em>')
            $config | Add-Member -NotePropertyName heroCta -Force -NotePropertyValue ([pscustomobject]@{
                label = 'Open <files>'
                url = "Documents?view=all&owner=O'Reilly"
            })
        }
        $sections = [Collections.Generic.List[object]]::new()
        $controls = [Collections.Generic.List[object]]::new()
        $page = @{ Sections = $sections; Controls = $controls }
        & (Join-Path $repositoryRoot "templates/$($config.template).ps1") `
            -Page $page -Configuration $config -SiteUrl $config.siteUrl `
            -HeroImageUrl $imageUrl -HeroImageAlt $imageAlt -AccentColor $config.accentColor `
            -PrimaryLibraryId $listId -PrimaryLibraryTitle $config.libraries[0].title

        $orders = @($sections | ForEach-Object { $_.Order })
        if (($orders -join ',') -ne ((1..$sections.Count) -join ',')) { throw 'Section order has gaps.' }
        foreach ($control in $controls) {
            $options = $control.Options
            $section = $sections[$options.Section - 1]
            $columnCount = if ($section.SectionTemplate -eq 'OneColumn') { 1 } else { 2 }
            if ($options.Column -lt 1 -or $options.Column -gt $columnCount) { throw 'Invalid column.' }
        }
        $positions = $controls | Group-Object { "$($_.Options.Section)/$($_.Options.Column)/$($_.Options.Order)" }
        if ($positions | Where-Object Count -gt 1) { throw 'Duplicate control position.' }
        $links = @($controls | Where-Object Kind -eq 'QuickLinks')
        if ($links.Count -ne [int]($config.quickLinks.Count -gt 0)) { throw 'Incorrect Quick Links count.' }
        if ($links.Count) {
            $payload = $links[0].Options.WebPartProperties | ConvertFrom-Json -AsHashtable
            if ($payload.properties.items -isnot [array] -or $payload.properties.items.Count -ne $config.quickLinks.Count) {
                throw 'Quick Links must retain an array, including a single link.'
            }
            for ($index = 0; $index -lt $config.quickLinks.Count; $index++) {
                $expectedUrl = [Uri]::new([Uri]"$($config.siteUrl)/", $config.quickLinks[$index].url).AbsoluteUri
                if ($payload.serverProcessedContent.links["items[$index].sourceItem.url"] -ne $expectedUrl -or
                    $payload.serverProcessedContent.searchablePlainTexts["items[$index].title"] -ne $config.quickLinks[$index].label -or
                    $payload.properties.items[$index].description -ne $config.libraries[$index].description) {
                    throw 'Quick Links lost their URL, label or library description.'
                }
            }
        }
        $html = ($controls | Where-Object Kind -eq 'Text' | ForEach-Object { $_.Options.Text }) -join "`n"
        if ($html -match '<script>|<em>|Add the right people|MEET THE TEAM') { throw 'Unescaped text or placeholder leaked.' }
        if ($variant -eq 'single-link' -and $html -notmatch 'A &amp; B &lt;C&gt;') { throw 'Title was not HTML encoded.' }
        if ($variant -eq 'single-link' -and ($html -notmatch 'Open &lt;files&gt;' -or $html -notmatch '&amp;owner=O&#39;Reilly')) {
            throw 'CTA text or URL was not HTML encoded.'
        }
        if ($variant -eq 'configured') {
            if (-not $html.Contains([Net.WebUtility]::HtmlEncode($config.page.description))) { throw 'Detailed description was lost.' }
            if ($controls | Where-Object Kind -eq 'People') { throw 'Empty People web part was added.' }
            @{ Name = $config.siteTitle; Configuration = $config; Sections = @($sections.ToArray()); Controls = @($controls.ToArray()) }
        }
    }
})

. (Join-Path $repositoryRoot 'templates/PageComponents.ps1')
foreach ($url in @('javascript:alert(1)', 'data:text/html,test')) {
    $rejected = $false
    try { $null = Resolve-PnPPageLink -SiteUrl 'https://example.com/sites/test' -Url $url }
    catch { $rejected = $true }
    if (-not $rejected) { throw "Unsafe link accepted: $url" }
}
if ($captures.Count -eq 0) { throw 'No site configurations were tested.' }
if ($CapturePath) {
    $captures | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $CapturePath
}
Write-Host "Templates passed for $($captures.Count) sites, including minimal and single-link variants."

[CmdletBinding()]
param(
    [Parameter(Mandatory)] $Page,
    [Parameter(Mandatory)] $Configuration,
    [Parameter(Mandatory)] [string] $SiteUrl,
    [string] $HeroImageUrl,
    [string] $HeroImageAlt,
    [string] $AccentColor,
    [string] $PrimaryLibraryId,
    [string] $PrimaryLibraryTitle
)

. "$PSScriptRoot/PageComponents.ps1"

$heroLinkText = $null
$heroLinkUrl = $null
if ($Configuration.heroCta) {
    $siteBaseUrl = "$($SiteUrl.TrimEnd('/'))/"
    $heroLinkText = $Configuration.heroCta.label
    $heroLinkUrl = [System.Uri]::new([System.Uri]$siteBaseUrl, $Configuration.heroCta.url).AbsoluteUri
}

Add-PnPPageSection -Page $Page -SectionTemplate OneColumnVerticalSection -Order 1 -ZoneEmphasis 2 -VerticalZoneEmphasis 1 | Out-Null
Add-PnPHeroBanner -Page $Page -Section 1 `
    -Title $Configuration.page.title `
    -Description $Configuration.page.description `
    -ImageUrl $HeroImageUrl `
    -ImageAlt $HeroImageAlt `
    -LinkText $heroLinkText `
    -LinkUrl $heroLinkUrl `
    -AccentColor $AccentColor

$nextOrder = 2
Add-PnPIconLinkGrid -Page $Page -Links $Configuration.quickLinks -SiteUrl $SiteUrl `
    -Order $nextOrder -HeadingText 'Quick links' -AccentColor $AccentColor
$nextOrder++

Add-PnPDocumentsSection -Page $Page -Order $nextOrder -ListId $PrimaryLibraryId `
    -HeadingText $PrimaryLibraryTitle -AccentColor $AccentColor
$nextOrder++

if ($Configuration.importantDates.Count -gt 0) {
    Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order $nextOrder -ZoneEmphasis 3 | Out-Null
    $dateItems = foreach ($date in $Configuration.importantDates) {
        "<li>$date</li>"
    }
    $datesHtml = "<h2 style='color:$AccentColor;'>IMPORTANT DATES</h2><ul>$($dateItems -join '')</ul>"
    Add-PnPPageTextPart -Page $Page -Section $nextOrder -Column 1 -Order 1 -Text $datesHtml | Out-Null
    $nextOrder++
}

Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order $nextOrder -ZoneEmphasis 0 | Out-Null
Add-PnPPageTextPart -Page $Page -Section $nextOrder -Column 1 -Order 1 `
    -Text "<h2 style='color:$AccentColor;'>UPCOMING EVENTS</h2>" | Out-Null
Add-PnPPageWebPart -Page $Page -DefaultWebPartType Events -Section $nextOrder -Column 1 -Order 2 | Out-Null
$nextOrder++

Add-PnPPageSidebar -Page $Page -AccentColor $AccentColor

[CmdletBinding()]
param(
    [Parameter(Mandatory)] $Page,
    [Parameter(Mandatory)] $Configuration,
    [Parameter(Mandatory)] [string] $SiteUrl,
    [string] $HeroImageUrl,
    [string] $HeroImageAlt
)

. "$PSScriptRoot/PageComponents.ps1"

Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order 1 -ZoneEmphasis 2
Add-PnPHeroBanner -Page $Page -Section 1 `
    -Title "📋 $($Configuration.page.title)" `
    -Description $Configuration.page.description `
    -ImageUrl $HeroImageUrl `
    -ImageAlt $HeroImageAlt

$nextOrder = Add-PnPLinkTileRows -Page $Page -Links $Configuration.quickLinks -SiteUrl $SiteUrl `
    -StartOrder 2 -HeadingText '🔗 Quick links'

if ($Configuration.importantDates.Count -gt 0) {
    Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order $nextOrder -ZoneEmphasis 3
    $dateItems = foreach ($date in $Configuration.importantDates) {
        "<li>🗓️ $date</li>"
    }
    $datesHtml = "<h2>📅 Important dates</h2><ul>$($dateItems -join '')</ul>"
    Add-PnPPageTextPart -Page $Page -Section $nextOrder -Column 1 -Order 1 -Text $datesHtml
    $nextOrder++
}

Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order $nextOrder -ZoneEmphasis 1
Add-PnPPageWebPart -Page $Page -DefaultWebPartType SiteActivity -Section $nextOrder -Column 1 -Order 1

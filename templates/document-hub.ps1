[CmdletBinding()]
param(
    [Parameter(Mandatory)] $Page,
    [Parameter(Mandatory)] $Configuration,
    [Parameter(Mandatory)] [string] $SiteUrl,
    [string] $HeroImageUrl,
    [string] $HeroImageAlt,
    [string] $AccentColor
)

. "$PSScriptRoot/PageComponents.ps1"

Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order 1 -ZoneEmphasis 2
Add-PnPHeroBanner -Page $Page -Section 1 `
    -Title "📋 $($Configuration.page.title)" `
    -Description $Configuration.page.description `
    -ImageUrl $HeroImageUrl `
    -ImageAlt $HeroImageAlt `
    -AccentColor $AccentColor

$nextOrder = 2
Add-PnPCalloutButtons -Page $Page -Links $Configuration.quickLinks -SiteUrl $SiteUrl `
    -Order $nextOrder -HeadingText '🔗 Quick links' -AccentColor $AccentColor
$nextOrder++

if ($Configuration.importantDates.Count -gt 0) {
    Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order $nextOrder -ZoneEmphasis 3
    $dateItems = foreach ($date in $Configuration.importantDates) {
        "<li>🗓️ $date</li>"
    }
    $datesHtml = "<h2 style='color:$AccentColor;'>📅 Important dates</h2><ul>$($dateItems -join '')</ul>"
    Add-PnPPageTextPart -Page $Page -Section $nextOrder -Column 1 -Order 1 -Text $datesHtml
    $nextOrder++
}

Add-PnPTeamContacts -Page $Page -Order $nextOrder -AccentColor $AccentColor
$nextOrder++

Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order $nextOrder -ZoneEmphasis 1
Add-PnPPageWebPart -Page $Page -DefaultWebPartType SiteActivity -Section $nextOrder -Column 1 -Order 1

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

Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order 1 -ZoneEmphasis 2 | Out-Null
Add-PnPHeroBanner -Page $Page -Section 1 `
    -Title "🏢 $($Configuration.page.title)" `
    -Description $Configuration.page.description `
    -ImageUrl $HeroImageUrl `
    -ImageAlt $HeroImageAlt `
    -AccentColor $AccentColor

$nextOrder = 2
Add-PnPCalloutButtons -Page $Page -Links $Configuration.quickLinks -SiteUrl $SiteUrl `
    -Order $nextOrder -HeadingText '🔗 Quick links' -AccentColor $AccentColor
$nextOrder++

Add-PnPTeamContacts -Page $Page -Order $nextOrder -AccentColor $AccentColor
$nextOrder++

Add-PnPPageSection -Page $Page -SectionTemplate TwoColumnLeft -Order $nextOrder -ZoneEmphasis 3 | Out-Null
Add-PnPPageWebPart -Page $Page -DefaultWebPartType News -Section $nextOrder -Column 1 -Order 1 | Out-Null
Add-PnPPageWebPart -Page $Page -DefaultWebPartType Events -Section $nextOrder -Column 2 -Order 1 | Out-Null

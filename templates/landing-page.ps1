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
    -Title "🏢 $($Configuration.page.title)" `
    -Description $Configuration.page.description `
    -ImageUrl $HeroImageUrl `
    -ImageAlt $HeroImageAlt

$nextOrder = Add-PnPLinkTileRows -Page $Page -Links $Configuration.quickLinks -SiteUrl $SiteUrl `
    -StartOrder 2 -HeadingText '🔗 Quick links'

Add-PnPPageSection -Page $Page -SectionTemplate TwoColumnLeft -Order $nextOrder -ZoneEmphasis 3
Add-PnPPageWebPart -Page $Page -DefaultWebPartType News -Section $nextOrder -Column 1 -Order 1
Add-PnPPageWebPart -Page $Page -DefaultWebPartType Events -Section $nextOrder -Column 2 -Order 1

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

Add-PnPHeroBanner -Page $Page -Configuration $Configuration -SiteUrl $SiteUrl `
    -ImageUrl $HeroImageUrl -ImageAlt $HeroImageAlt -AccentColor $AccentColor

$nextOrder = 2
if ($Configuration.quickLinks.Count -gt 0) {
    Add-PnPQuickLinks -Page $Page -Links $Configuration.quickLinks -Libraries $Configuration.libraries `
        -SiteUrl $SiteUrl -Order $nextOrder
    $nextOrder++
}

Add-PnPDocumentsSection -Page $Page -Order $nextOrder -ListId $PrimaryLibraryId `
    -HeadingText $PrimaryLibraryTitle -AccentColor $AccentColor
$nextOrder++

$eventColumn = 1
$layout = 'OneColumn'
if ($Configuration.importantDates.Count -gt 0) {
    $layout = 'TwoColumn'
    $eventColumn = 2
}
Add-PnPPageSection -Page $Page -SectionTemplate $layout -Order $nextOrder -ZoneEmphasis 0 | Out-Null
if ($Configuration.importantDates.Count -gt 0) {
    $dateItems = foreach ($date in $Configuration.importantDates) {
        "<li>$([Net.WebUtility]::HtmlEncode($date))</li>"
    }
    Add-PnPPageTextPart -Page $Page -Section $nextOrder -Column 1 -Order 1 `
        -Text "<h2 style='color:$AccentColor;'>Planning reminders</h2><ul>$($dateItems -join '')</ul>" | Out-Null
}
Add-PnPPageTextPart -Page $Page -Section $nextOrder -Column $eventColumn -Order 1 `
    -Text "<h2 style='color:$AccentColor;'>Upcoming events</h2>" | Out-Null
Add-PnPPageWebPart -Page $Page -DefaultWebPartType Events -Section $nextOrder -Column $eventColumn -Order 2 | Out-Null
$nextOrder++

Add-PnPAboutSection -Page $Page -Configuration $Configuration -Order $nextOrder -AccentColor $AccentColor

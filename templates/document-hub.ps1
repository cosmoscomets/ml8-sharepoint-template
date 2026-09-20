[CmdletBinding()]
param(
    [Parameter(Mandatory)] $Page,
    [Parameter(Mandatory)] $Configuration,
    [Parameter(Mandatory)] [string] $SiteUrl
)

Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order 1 -ZoneEmphasis 2

$introHtml = @"
<h1>📋 $($Configuration.page.title)</h1>
<p>$($Configuration.page.description)</p>
"@
Add-PnPPageTextPart -Page $Page -Section 1 -Column 1 -Order 1 -Text $introHtml

Add-PnPPageSection -Page $Page -SectionTemplate TwoColumnLeft -Order 2 -ZoneEmphasis 1

$quickLinkItems = foreach ($quickLink in $Configuration.quickLinks) {
    $siteBaseUrl = "$($SiteUrl.TrimEnd('/'))/"
    $absoluteUrl = [System.Uri]::new([System.Uri]$siteBaseUrl, $quickLink.url).AbsoluteUri
    "<li>📁 <a href='$absoluteUrl'>$($quickLink.label)</a></li>"
}
$quickLinksHtml = "<h2>🔗 Quick links</h2><ul>$($quickLinkItems -join '')</ul>"
Add-PnPPageTextPart -Page $Page -Section 2 -Column 1 -Order 1 -Text $quickLinksHtml

$dateItems = foreach ($date in $Configuration.importantDates) {
    "<li>🗓️ $date</li>"
}
$datesHtml = "<h2>📅 Important dates</h2><ul>$($dateItems -join '')</ul>"
Add-PnPPageTextPart -Page $Page -Section 2 -Column 2 -Order 1 -Text $datesHtml

Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order 3 -ZoneEmphasis 3
Add-PnPPageWebPart `
    -Page $Page `
    -DefaultWebPartType SiteActivity `
    -Section 3 `
    -Column 1 `
    -Order 1

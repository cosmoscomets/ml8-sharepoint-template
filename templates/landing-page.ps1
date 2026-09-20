[CmdletBinding()]
param(
    [Parameter(Mandatory)] $Page,
    [Parameter(Mandatory)] $Configuration,
    [Parameter(Mandatory)] [string] $SiteUrl
)

Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order 1 -ZoneEmphasis 2

$introHtml = @"
<h1>🏢 $($Configuration.page.title)</h1>
<p>$($Configuration.page.description)</p>
"@
Add-PnPPageTextPart -Page $Page -Section 1 -Column 1 -Order 1 -Text $introHtml

Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order 2 -ZoneEmphasis 1

$quickLinkItems = foreach ($quickLink in $Configuration.quickLinks) {
    $siteBaseUrl = "$($SiteUrl.TrimEnd('/'))/"
    $absoluteUrl = [System.Uri]::new([System.Uri]$siteBaseUrl, $quickLink.url).AbsoluteUri
    "<li>📁 <a href='$absoluteUrl'>$($quickLink.label)</a></li>"
}
$quickLinksHtml = "<h2>🔗 Quick links</h2><ul>$($quickLinkItems -join '')</ul>"
Add-PnPPageTextPart -Page $Page -Section 2 -Column 1 -Order 1 -Text $quickLinksHtml

Add-PnPPageSection -Page $Page -SectionTemplate TwoColumnLeft -Order 3 -ZoneEmphasis 3
Add-PnPPageWebPart -Page $Page -DefaultWebPartType News -Section 3 -Column 1 -Order 1
Add-PnPPageWebPart -Page $Page -DefaultWebPartType Events -Section 3 -Column 2 -Order 1

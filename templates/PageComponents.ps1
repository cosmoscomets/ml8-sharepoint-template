function Add-PnPHeroBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Page,
        [Parameter(Mandatory)] [int] $Section,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $Description,
        [string] $ImageUrl,
        [string] $ImageAlt
    )

    $order = 1
    if ($ImageUrl) {
        Add-PnPPageImageWebPart -Page $Page -Section $Section -Column 1 -Order $order `
            -ImageUrl $ImageUrl -AlternativeText $ImageAlt -ImageWidth 1200 -ImageHeight 400
        $order++
    }

    $introHtml = @"
<h1>$Title</h1>
<p>$Description</p>
"@
    Add-PnPPageTextPart -Page $Page -Section $Section -Column 1 -Order $order -Text $introHtml
}

function Add-PnPLinkTileRows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Page,
        [Parameter(Mandatory)] [array] $Links,
        [Parameter(Mandatory)] [string] $SiteUrl,
        [Parameter(Mandatory)] [int] $StartOrder,
        [string] $HeadingText
    )

    $order = $StartOrder

    if ($HeadingText) {
        Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order $order -ZoneEmphasis 0
        Add-PnPPageTextPart -Page $Page -Section $order -Column 1 -Order 1 -Text "<h2>$HeadingText</h2>"
        $order++
    }

    $sectionTemplateByCount = @{ 1 = 'OneColumn'; 2 = 'TwoColumn'; 3 = 'ThreeColumn' }
    $siteBaseUrl = "$($SiteUrl.TrimEnd('/'))/"

    for ($i = 0; $i -lt $Links.Count; $i += 3) {
        $chunk = @($Links[$i..([Math]::Min($i + 2, $Links.Count - 1))])
        Add-PnPPageSection -Page $Page -SectionTemplate $sectionTemplateByCount[$chunk.Count] -Order $order -ZoneEmphasis 1

        $column = 1
        foreach ($link in $chunk) {
            $absoluteUrl = [System.Uri]::new([System.Uri]$siteBaseUrl, $link.url).AbsoluteUri
            if ($link.imageUrl) {
                Add-PnPPageImageWebPart -Page $Page -Section $order -Column $column -Order 1 `
                    -ImageUrl $link.imageUrl -Caption $link.label -Link $absoluteUrl `
                    -AlternativeText $link.image.alt -ImageWidth 400 -ImageHeight 260
            }
            else {
                Add-PnPPageTextPart -Page $Page -Section $order -Column $column -Order 1 `
                    -Text "<p>📁 <a href='$absoluteUrl'>$($link.label)</a></p>"
            }
            $column++
        }

        $order++
    }

    return $order
}

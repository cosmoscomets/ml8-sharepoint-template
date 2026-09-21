function Add-PnPHeroBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Page,
        [Parameter(Mandatory)] [int] $Section,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $Description,
        [string] $ImageUrl,
        [string] $ImageAlt,
        [string] $AccentColor
    )

    $order = 1
    if ($ImageUrl) {
        Add-PnPPageImageWebPart -Page $Page -Section $Section -Column 1 -Order $order `
            -ImageUrl $ImageUrl -AlternativeText $ImageAlt -ImageWidth 1200 -ImageHeight 400 | Out-Null
        $order++
    }

    $introHtml = @"
<h1 style="color:$AccentColor;">$Title</h1>
<p>$Description</p>
"@
    Add-PnPPageTextPart -Page $Page -Section $Section -Column 1 -Order $order -Text $introHtml | Out-Null
}

function Add-PnPCalloutButtons {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Page,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [array] $Links,
        [Parameter(Mandatory)] [string] $SiteUrl,
        [Parameter(Mandatory)] [int] $Order,
        [string] $HeadingText,
        [string] $AccentColor
    )

    if ($Links.Count -eq 0) {
        return
    }

    Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order $Order -ZoneEmphasis 0 | Out-Null

    $siteBaseUrl = "$($SiteUrl.TrimEnd('/'))/"
    $buttonsHtml = foreach ($link in $Links) {
        $absoluteUrl = [System.Uri]::new([System.Uri]$siteBaseUrl, $link.url).AbsoluteUri
        "<a href='$absoluteUrl' style='background-color:$AccentColor;color:#ffffff;padding:14px 22px;border-radius:4px;text-decoration:none;font-weight:600;display:inline-block;margin:4px 8px 4px 0;'>$($link.label) &raquo;</a>"
    }

    $headingHtml = ''
    if ($HeadingText) {
        $headingHtml = "<h2 style='color:$AccentColor;'>$HeadingText</h2>"
    }

    Add-PnPPageTextPart -Page $Page -Section $Order -Column 1 -Order 1 `
        -Text "$headingHtml<div>$($buttonsHtml -join '')</div>" | Out-Null
}

function Add-PnPTeamContacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Page,
        [Parameter(Mandatory)] [int] $Order,
        [string] $HeadingText = 'Meet the team',
        [string] $AccentColor
    )

    Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order $Order -ZoneEmphasis 0 | Out-Null
    Add-PnPPageTextPart -Page $Page -Section $Order -Column 1 -Order 1 `
        -Text "<h2 style='color:$AccentColor;'>$HeadingText</h2><p>Add the right people to this card in the page editor.</p>" | Out-Null
    Add-PnPPageWebPart -Page $Page -DefaultWebPartType People -Section $Order -Column 1 -Order 2 | Out-Null
}

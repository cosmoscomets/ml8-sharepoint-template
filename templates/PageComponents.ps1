function Add-PnPHeroBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Page,
        [Parameter(Mandatory)] [int] $Section,
        [Parameter(Mandatory)] [string] $Title,
        [Parameter(Mandatory)] [string] $Description,
        [string] $ImageUrl,
        [string] $ImageAlt,
        [string] $LinkText,
        [string] $LinkUrl,
        [string] $AccentColor
    )

    $order = 1
    if ($ImageUrl) {
        Add-PnPPageImageWebPart -Page $Page -Section $Section -Column 1 -Order $order `
            -ImageUrl $ImageUrl -AlternativeText $ImageAlt -ImageWidth 1920 -ImageHeight 640 | Out-Null
        $order++
    }

    $linkHtml = ''
    if ($LinkText -and $LinkUrl) {
        $linkHtml = "<p><a href='$LinkUrl' style='background-color:$AccentColor;color:#ffffff;padding:14px 22px;border-radius:4px;text-decoration:none;font-weight:600;display:inline-block;margin:8px 0 0;'>$LinkText &raquo;</a></p>"
    }

    $introHtml = @"
<h1 style="color:$AccentColor;">$($Title.ToUpper())</h1>
<p>$Description</p>
$linkHtml
"@
    Add-PnPPageTextPart -Page $Page -Section $Section -Column 1 -Order $order -Text $introHtml | Out-Null
}

function Add-PnPIconLinkGrid {
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
    $tilesHtml = foreach ($link in $Links) {
        $absoluteUrl = [System.Uri]::new([System.Uri]$siteBaseUrl, $link.url).AbsoluteUri
        "<a href='$absoluteUrl' style='background-color:#f3f2f1;color:#201f1e;padding:12px 20px;border-radius:4px;text-decoration:none;font-weight:600;display:inline-block;margin:4px 8px 4px 0;'>$($link.label.ToUpper())</a>"
    }

    $headingHtml = ''
    if ($HeadingText) {
        $headingHtml = "<h2 style='color:$AccentColor;'>$($HeadingText.ToUpper())</h2>"
    }

    Add-PnPPageTextPart -Page $Page -Section $Order -Column 1 -Order 1 `
        -Text "$headingHtml<div>$($tilesHtml -join '')</div>" | Out-Null
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
        "<a href='$absoluteUrl' style='background-color:$AccentColor;color:#ffffff;padding:14px 22px;border-radius:4px;text-decoration:none;font-weight:600;display:inline-block;margin:4px 8px 4px 0;'>$($link.label.ToUpper()) &raquo;</a>"
    }

    $headingHtml = ''
    if ($HeadingText) {
        $headingHtml = "<h2 style='color:$AccentColor;'>$($HeadingText.ToUpper())</h2>"
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
        -Text "<h2 style='color:$AccentColor;'>$($HeadingText.ToUpper())</h2><p>Add the right people to this card in the page editor.</p>" | Out-Null
    Add-PnPPageWebPart -Page $Page -DefaultWebPartType People -Section $Order -Column 1 -Order 2 | Out-Null
}

function Add-PnPDocumentsSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Page,
        [Parameter(Mandatory)] [int] $Order,
        [string] $ListId,
        [string] $HeadingText,
        [string] $AccentColor
    )

    if (-not $ListId) {
        return
    }

    if (-not $HeadingText) {
        $HeadingText = 'Documents'
    }

    Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order $Order -ZoneEmphasis 1 | Out-Null
    Add-PnPPageTextPart -Page $Page -Section $Order -Column 1 -Order 1 `
        -Text "<h2 style='color:$AccentColor;'>$($HeadingText.ToUpper())</h2>" | Out-Null
    Add-PnPPageWebPart -Page $Page -DefaultWebPartType List -Section $Order -Column 1 -Order 2 `
        -WebPartProperties @{ isDocumentLibrary = 'true'; selectedListId = $ListId } | Out-Null
}

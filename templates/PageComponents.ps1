function Resolve-PnPPageLink {
    param([string] $SiteUrl, [string] $Url)

    $resolved = [Uri]::new([Uri]"$($SiteUrl.TrimEnd('/'))/", $Url)
    if ($resolved.Scheme -notin @('https', 'http')) {
        throw "Page links must use http or https: $Url"
    }
    return $resolved.AbsoluteUri
}

function Add-PnPHeroBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Page,
        [Parameter(Mandatory)] $Configuration,
        [Parameter(Mandatory)] [string] $SiteUrl,
        [string] $ImageUrl,
        [string] $ImageAlt,
        [string] $AccentColor
    )

    $layout = if ($ImageUrl) { 'TwoColumnRight' } else { 'OneColumn' }
    Add-PnPPageSection -Page $Page -SectionTemplate $layout -Order 1 -ZoneEmphasis 0 | Out-Null

    $description = $Configuration.page.description
    if ($Configuration.page.PSObject.Properties['summary'] -and $Configuration.page.summary) {
        $description = $Configuration.page.summary
    }
    $title = [Net.WebUtility]::HtmlEncode($Configuration.page.title)
    $description = [Net.WebUtility]::HtmlEncode($description)
    $linkHtml = ''
    if ($Configuration.PSObject.Properties['heroCta'] -and $Configuration.heroCta) {
        $url = [Net.WebUtility]::HtmlEncode((Resolve-PnPPageLink -SiteUrl $SiteUrl -Url $Configuration.heroCta.url))
        $label = [Net.WebUtility]::HtmlEncode($Configuration.heroCta.label)
        $linkHtml = "<p><a href='$url'><strong>$label &rarr;</strong></a></p>"
    }

    Add-PnPPageTextPart -Page $Page -Section 1 -Column 1 -Order 1 -Text @"
<p>Moonlight Resources</p>
<h1 style="color:$AccentColor;">$title</h1>
<p>$description</p>
$linkHtml
"@ | Out-Null

    if ($ImageUrl) {
        Add-PnPPageImageWebPart -Page $Page -Section 1 -Column 2 -Order 1 `
            -ImageUrl $ImageUrl -AlternativeText $ImageAlt -ImageWidth 1920 -ImageHeight 640 | Out-Null
    }
}

function Add-PnPQuickLinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $Page,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [array] $Links,
        [Parameter(Mandatory)] [array] $Libraries,
        [Parameter(Mandatory)] [string] $SiteUrl,
        [Parameter(Mandatory)] [int] $Order
    )

    if ($Links.Count -eq 0) { return }

    $texts = @{ title = 'Explore this site' }
    $urls = @{ baseUrl = $SiteUrl.TrimEnd('/') }
    $items = @(for ($index = 0; $index -lt $Links.Count; $index++) {
        $link = $Links[$index]
        $url = Resolve-PnPPageLink -SiteUrl $SiteUrl -Url $link.url
        $library = $Libraries | Where-Object {
            (Resolve-PnPPageLink -SiteUrl $SiteUrl -Url $_.url) -eq $url
        } | Select-Object -First 1
        $description = if ($library) { $library.description } else { '' }
        $texts["items[$index].title"] = $link.label
        $texts["items[$index].description"] = $description
        $urls["items[$index].sourceItem.url"] = $url
        @{
            id = $index + 1
            sourceItem = @{ itemType = 2; fileExtension = ''; progId = '' }
            thumbnailType = 2
            fabricReactIcon = @{ iconName = $(if ($library) { 'FabricFolder' } else { 'Link' }) }
            description = $description
            altText = ''
        }
    })

    # Native Quick Links keeps layout, keyboard focus and mobile wrapping in SharePoint.
    # Payload shape: https://pnp.github.io/script-samples/spo-create-modern-pages-add-web-parts/README.html
    $properties = @{
        title = 'Quick links'
        dataVersion = '2.2'
        serverProcessedContent = @{ searchablePlainTexts = $texts; links = $urls }
        properties = @{
            items = $items
            isMigrated = $true
            layoutId = 'Button'
            shouldShowThumbnail = $true
            buttonLayoutOptions = @{
                showDescription = $true
                buttonTreatment = 1
                iconPositionType = 2
                textAlignmentVertical = 2
                textAlignmentHorizontal = 1
                linesOfText = 2
            }
            hideWebPartWhenEmpty = $true
            dataProviderId = 'QuickLinks'
        }
    } | ConvertTo-Json -Depth 10 -Compress

    Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order $Order -ZoneEmphasis 0 | Out-Null
    Add-PnPPageWebPart -Page $Page -DefaultWebPartType QuickLinks -Section $Order -Column 1 -Order 1 `
        -WebPartProperties $properties | Out-Null
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

    $layout = if ($ListId) { 'TwoColumnLeft' } else { 'OneColumn' }
    Add-PnPPageSection -Page $Page -SectionTemplate $layout -Order $Order -ZoneEmphasis 1 | Out-Null
    $activityColumn = 1
    if ($ListId) {
        if (-not $HeadingText) { $HeadingText = 'Documents' }
        $heading = [Net.WebUtility]::HtmlEncode($HeadingText)
        Add-PnPPageTextPart -Page $Page -Section $Order -Column 1 -Order 1 `
            -Text "<h2 style='color:$AccentColor;'>$heading</h2>" | Out-Null
        Add-PnPPageWebPart -Page $Page -DefaultWebPartType List -Section $Order -Column 1 -Order 2 `
            -WebPartProperties @{ isDocumentLibrary = 'true'; selectedListId = $ListId } | Out-Null
        $activityColumn = 2
    }

    Add-PnPPageTextPart -Page $Page -Section $Order -Column $activityColumn -Order 1 `
        -Text "<h2 style='color:$AccentColor;'>Recent activity</h2>" | Out-Null
    Add-PnPPageWebPart -Page $Page -DefaultWebPartType SiteActivity -Section $Order -Column $activityColumn -Order 2 | Out-Null
}

function Add-PnPAboutSection {
    param($Page, $Configuration, [int] $Order, [string] $AccentColor)

    if ($Configuration.page.PSObject.Properties['summary'] -and $Configuration.page.summary -and
        $Configuration.page.description) {
        $description = [Net.WebUtility]::HtmlEncode($Configuration.page.description)
        Add-PnPPageSection -Page $Page -SectionTemplate OneColumn -Order $Order -ZoneEmphasis 0 | Out-Null
        Add-PnPPageTextPart -Page $Page -Section $Order -Column 1 -Order 1 `
            -Text "<h2 style='color:$AccentColor;'>About this site</h2><p>$description</p>" | Out-Null
    }
}

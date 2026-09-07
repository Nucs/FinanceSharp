#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $SiteDirectory
)

$ErrorActionPreference = 'Stop'
$siteRoot = (Resolve-Path -LiteralPath $SiteDirectory).Path
$rootPrefix = $siteRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$failures = [Collections.Generic.List[string]]::new()

function Resolve-SiteFile([string] $BaseDirectory, [string] $RelativePath) {
    $path = [IO.Path]::GetFullPath((Join-Path $BaseDirectory $RelativePath))
    if (-not $path.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -and $path -ne $siteRoot) {
        throw "Documentation link escapes the site: $RelativePath"
    }
    return $path
}

$required = @(
    'index.html', 'toc.html', 'toc.json', 'articles/intro.html', 'articles/documentation.html',
    'api/index.html', 'api/toc.html', 'api/toc.json',
    'api/FinanceSharp.html', 'api/FinanceSharp.DoubleArray.html',
    'api/FinanceSharp.Indicators.IndicatorBase.html',
    'api/FinanceSharp.Indicators.SimpleMovingAverage.html',
    'public/docfx.min.css', 'public/docfx.min.js', 'public/main.css', 'public/main.js',
    'images/logo.png', 'manifest.json', 'xrefmap.yml', 'sitemap.xml', 'index.json',
    'llms.txt', 'llms-full.txt', 'robots.txt', '.nojekyll'
)
foreach ($relativePath in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $siteRoot $relativePath) -PathType Leaf)) {
        $failures.Add("Missing expected build output: $relativePath")
    }
}
if ($failures.Count) { throw ($failures -join "`n") }

$manifest = Get-Content -LiteralPath (Join-Path $siteRoot 'manifest.json') -Raw | ConvertFrom-Json -AsHashtable
$pages = @($manifest.files | Where-Object { $_.type -in @('Conceptual', 'ManagedReference') })
$apiPages = @($pages | Where-Object type -eq 'ManagedReference')
if ($apiPages.Count -eq 0) { $failures.Add('No generated API pages in the build manifest.') }
$search = Get-Content -LiteralPath (Join-Path $siteRoot 'index.json') -Raw | ConvertFrom-Json -AsHashtable
$fullExport = Get-Content -LiteralPath (Join-Path $siteRoot 'llms-full.txt') -Raw
$linkExport = Get-Content -LiteralPath (Join-Path $siteRoot 'llms.txt') -Raw
$siteUrl = $manifest.sitemap.baseUrl.TrimEnd('/') + '/'
$navigation = Get-Content -LiteralPath (Join-Path $siteRoot 'toc.json') -Raw | ConvertFrom-Json -AsHashtable
$apiNavigation = @($navigation.items | Where-Object { $_['tocHref'] -eq 'api/toc.html' })
if ($apiNavigation.Count -ne 1) {
    $failures.Add('Global navigation must link to a separate API sidebar TOC.')
}

$htmlFiles = @(Get-ChildItem -LiteralPath $siteRoot -Recurse -Filter '*.html' -File)
$htmlByPath = @{}
$idsByPath = @{}
foreach ($file in $htmlFiles) {
    $html = Get-Content -LiteralPath $file.FullName -Raw
    $htmlByPath[$file.FullName] = $html
    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($match in [regex]::Matches($html, '\bid="([^"]+)"|<a\b[^>]*\bname="([^"]+)"')) {
        $id = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
        $null = $ids.Add([Net.WebUtility]::HtmlDecode($id))
    }
    $idsByPath[$file.FullName] = $ids
}

$checkedLinks = 0
foreach ($file in $htmlFiles) {
    foreach ($match in [regex]::Matches($htmlByPath[$file.FullName], '\b(?:href|src)="([^"]+)"')) {
        $href = [Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
        if ($href -match '^(?:[a-zA-Z][a-zA-Z0-9+.-]*:|//)' -or $href -eq '') { continue }
        $parts = $href -split '#', 2
        $relativePath = [Uri]::UnescapeDataString(($parts[0] -split '\?', 2)[0])
        $target = if ($relativePath) { Resolve-SiteFile $file.DirectoryName $relativePath } else { $file.FullName }
        if (Test-Path -LiteralPath $target -PathType Container) { $target = Join-Path $target 'index.html' }
        $checkedLinks++
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            $failures.Add("Broken local link in $($file.Name): $href")
            continue
        }
        if ($parts.Count -eq 2 -and $parts[1] -and [IO.Path]::GetExtension($target) -eq '.html') {
            $fragment = [Uri]::UnescapeDataString($parts[1])
            if ($fragment -notmatch '^:~:text=' -and -not $idsByPath[$target].Contains($fragment)) {
                $failures.Add("Missing HTML fragment in $($file.Name): $href")
            }
        }
    }
}

foreach ($page in $pages) {
    $relativePath = $page.output['.html'].relative_path
    $target = Resolve-SiteFile $siteRoot $relativePath
    if (-not $htmlByPath.ContainsKey($target)) {
        $failures.Add("Manifest article was not rendered: $relativePath")
        continue
    }
    if (-not $search.ContainsKey($relativePath) -or -not $search[$relativePath].summary) {
        $failures.Add("Rendered article missing from search: $relativePath")
    }
    $pageUrl = [Uri]::new([Uri]$siteUrl, $relativePath).AbsoluteUri
    if (-not $fullExport.Contains('Source: ' + $pageUrl) -or -not $linkExport.Contains('](' + $pageUrl + ')')) {
        $failures.Add("Rendered article missing from LLM exports: $relativePath")
    }
    if ($page.type -eq 'ManagedReference' -and $htmlByPath[$target] -notmatch '<article\b[^>]*data-uid="FinanceSharp') {
        $failures.Add("API page has no FinanceSharp API identity: $relativePath")
    }
}

$movingAverage = $htmlByPath[(Join-Path $siteRoot 'api/FinanceSharp.Indicators.SimpleMovingAverage.html')]
if ($movingAverage -notmatch 'class SimpleMovingAverage' -or $movingAverage -notmatch 'github\.com/Nucs/FinanceSharp/blob/.+?/src/FinanceSharp/Indicators/SimpleMovingAverage\.cs') {
    $failures.Add('SimpleMovingAverage API page is missing its generated C# declaration or source link.')
}
if ($fullExport -notmatch 'class SimpleMovingAverage' -or $fullExport -notmatch 'DoubleArray') {
    $failures.Add('Full LLM export is missing generated API declarations.')
}

if ($failures.Count) {
    $failures | Select-Object -First 30 | ForEach-Object { Write-Host $_ }
    throw "$($failures.Count) documentation validation failure(s)."
}
Write-Host "Verified $($pages.Count) articles ($($apiPages.Count) API), $($htmlFiles.Count) HTML files, $checkedLinks local links/fragments, search, source links, and complete LLM exports."

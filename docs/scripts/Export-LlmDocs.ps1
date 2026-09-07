#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $SiteDirectory,
    [string] $SiteUrl
)

$ErrorActionPreference = 'Stop'
$siteRoot = (Resolve-Path -LiteralPath $SiteDirectory).Path
$manifest = Get-Content -LiteralPath (Join-Path $siteRoot 'manifest.json') -Raw | ConvertFrom-Json -AsHashtable
if (-not $SiteUrl) { $SiteUrl = $manifest.sitemap.baseUrl }
$siteUri = [Uri]($SiteUrl.TrimEnd('/') + '/')
if (-not $siteUri.IsAbsoluteUri -or $siteUri.Scheme -notin @('http', 'https')) {
    throw 'SiteUrl must be an absolute HTTP(S) documentation URL.'
}

function Get-PlainText([string] $Html) {
    $text = [regex]::Replace($Html, '<[^>]+>', '')
    return [Net.WebUtility]::HtmlDecode($text)
}

function Remove-HtmlTags([string] $Html) {
    return [regex]::Replace($Html, '<[^>]+>', '')
}

function Convert-ArticleToMarkdown([string] $Html, [Uri] $PageUrl) {
    $article = [regex]::Match($Html, '(?s)<article\b[^>]*>(.*?)</article>')
    if (-not $article.Success) { throw "No article content found for $PageUrl" }
    $text = $article.Groups[1].Value
    $text = [regex]::Replace($text, '(?s)<(?:script|style|button)\b[^>]*>.*?</(?:script|style|button)>', '')
    $text = [regex]::Replace($text, '(?s)<pre\b[^>]*>\s*<code\b[^>]*>(.*?)</code>\s*</pre>', {
        param($match)
        "`n`n~~~`n" + (Remove-HtmlTags $match.Groups[1].Value).Trim() + "`n~~~`n`n"
    })
    $text = [regex]::Replace($text, '(?s)<h([1-6])\b[^>]*>(.*?)</h\1>', {
        param($match)
        "`n`n" + ('#' * [int]$match.Groups[1].Value) + ' ' + (Remove-HtmlTags $match.Groups[2].Value).Trim() + "`n`n"
    })
    $text = [regex]::Replace($text, '(?s)<a\b[^>]*href="([^"]+)"[^>]*>(.*?)</a>', {
        param($match)
        $label = (Remove-HtmlTags $match.Groups[2].Value).Trim()
        $href = [Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
        if (-not $label) { return '' }
        '[' + $label + '](' + [Uri]::new($PageUrl, $href).AbsoluteUri + ')'
    })
    $text = [regex]::Replace($text, '(?s)<code\b[^>]*>(.*?)</code>', '`$1`')
    $text = [regex]::Replace($text, '</?(?:p|div|section|table|ul|ol)\b[^>]*>', "`n`n")
    $text = [regex]::Replace($text, '<li\b[^>]*>', "`n- ")
    $text = [regex]::Replace($text, '</tr\s*>|<br\s*/?>', "`n")
    $text = [regex]::Replace($text, '</t[dh]\s*>', ' | ')
    $text = Get-PlainText $text
    $text = $text.Replace("`r`n", "`n")
    $text = [regex]::Replace($text, '(?m)^[ \t]+|[ \t]+$', '')
    return [regex]::Replace($text, '\n{3,}', "`n`n").Trim()
}

$pages = @($manifest.files | Where-Object { $_.type -in @('Conceptual', 'ManagedReference') } | Sort-Object { $_.output['.html'].relative_path })
if (-not ($pages | Where-Object type -eq 'ManagedReference')) {
    throw 'The completed DocFX manifest contains no generated API reference.'
}
$index = [Collections.Generic.List[string]]::new()
$full = [Collections.Generic.List[string]]::new()
$index.Add("# FinanceSharp`n`n> Technical indicators, market data consolidation, and connected computation graphs for .NET.`n")
$full.Add("# FinanceSharp documentation`n`n> Complete article content from this DocFX build, including guides and generated API members.`n")

foreach ($kind in @('Conceptual', 'ManagedReference')) {
    $heading = if ($kind -eq 'Conceptual') { 'Guides' } else { 'API reference' }
    $index.Add("`n## $heading`n")
    foreach ($page in $pages | Where-Object type -eq $kind) {
        $relativePath = $page.output['.html'].relative_path
        $html = Get-Content -LiteralPath (Join-Path $siteRoot $relativePath) -Raw
        $pageUrl = [Uri]::new($siteUri, $relativePath)
        $titleMatch = [regex]::Match($html, '(?s)<h1\b[^>]*>(.*?)</h1>')
        $title = (Get-PlainText $titleMatch.Groups[1].Value).Trim()
        if (-not $title) { throw "Missing page title in $relativePath" }
        $index.Add('- [' + $title + '](' + $pageUrl.AbsoluteUri + ')')
        $full.Add("`n---`n`nSource: " + $pageUrl.AbsoluteUri + "`n`n" + (Convert-ArticleToMarkdown $html $pageUrl) + "`n")
    }
}
$index.Add("`n## Optional`n`n- [Full documentation]($($siteUri.AbsoluteUri)llms-full.txt): All guides and API articles in one text file.`n- [Source repository](https://github.com/Nucs/FinanceSharp)`n")
[IO.File]::WriteAllText((Join-Path $siteRoot 'llms.txt'), ($index -join "`n"), [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $siteRoot 'llms-full.txt'), ($full -join "`n"), [Text.UTF8Encoding]::new($false))
$robots = "User-agent: *`nAllow: /`n`nSitemap: $($siteUri.AbsoluteUri)sitemap.xml`n"
[IO.File]::WriteAllText((Join-Path $siteRoot 'robots.txt'), $robots, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $siteRoot '.nojekyll'), '', [Text.UTF8Encoding]::new($false))
Write-Host "Exported $($pages.Count) documentation articles to llms.txt and llms-full.txt."

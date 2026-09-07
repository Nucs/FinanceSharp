#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $SiteDirectory,
    [string] $WorkDirectory
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$configuration = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docfx.json') -Raw | ConvertFrom-Json -AsHashtable

function Resolve-RepositoryPath([string] $Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $repositoryRoot $Path))
}

if (-not $WorkDirectory) {
    $WorkDirectory = Join-Path $repositoryRoot ('artifacts/docs/' + [Guid]::NewGuid().ToString('N'))
}
$workRoot = Resolve-RepositoryPath $WorkDirectory
$siteRoot = Resolve-RepositoryPath $SiteDirectory
if (Test-Path -LiteralPath $workRoot) {
    throw "WorkDirectory must be new so API generation cannot reuse stale metadata: $workRoot"
}
New-Item -ItemType Directory -Path $workRoot | Out-Null
$apiRoot = Join-Path $workRoot 'api'

foreach ($metadata in $configuration.metadata) {
    foreach ($source in $metadata.src) {
        $source.src = Resolve-RepositoryPath $(if ($source['src']) { $source['src'] } else { '.' })
    }
    $metadata.dest = $apiRoot
    if ($metadata.ContainsKey('output')) { $null = $metadata.Remove('output') }
    if ($metadata['filter']) { $metadata.filter = Resolve-RepositoryPath $metadata['filter'] }
}

foreach ($kind in @('content', 'resource', 'overwrite')) {
    foreach ($mapping in $configuration.build[$kind]) {
        $sourceRoot = Resolve-RepositoryPath $(if ($mapping['src']) { $mapping['src'] } else { '.' })
        # DocFX accepts sources outside the config directory only as relative paths.
        $mapping.src = [IO.Path]::GetRelativePath($workRoot, $sourceRoot)
        if ($kind -eq 'content') {
            # Authored API landing/overwrite Markdown stays in docs; generated YAML is fresh.
            $mapping.files = @($mapping.files | Where-Object { $_ -notin @('api/**/*.yml', 'toc.yml') })
        }
    }
}
$configuration.build.content += @{
    src = 'api'
    files = @('**/*.yml')
    dest = 'api'
}

# TOC discovery follows source paths, not output mappings. Keep the authored
# navigation, but resolve its API entry against this build's fresh metadata.
$docsRoot = Join-Path $repositoryRoot 'docs'
$toc = Get-Content -LiteralPath (Join-Path $docsRoot 'toc.yml') -Raw
$toc = [regex]::Replace($toc, '(?m)^(\s*(?:href|homepage):\s*)([^#\r\n]+)', {
    param($match)
    $target = $match.Groups[2].Value.Trim().Trim([char]34, [char]39)
    if ($target -match '^(?:[a-zA-Z][a-zA-Z0-9+.-]*:|//)') { return $match.Value }
    if ($match.Groups[1].Value.TrimStart().StartsWith('href:') -and $target -in @('api/', 'api/toc.yml')) {
        # A folder reference keeps the API tree in its sidebar. A direct toc.yml
        # reference would inline hundreds of API entries into the global navbar.
        return $match.Groups[1].Value + 'api/'
    } else {
        $resolved = [IO.Path]::GetFullPath((Join-Path $docsRoot $target))
    }
    $match.Groups[1].Value + [IO.Path]::GetRelativePath($workRoot, $resolved).Replace('\', '/')
})
$toc | Set-Content -LiteralPath (Join-Path $workRoot 'toc.yml') -Encoding utf8NoBOM
$configuration.build.content += @{ src = '.'; files = @('toc.yml') }
$configuration.build.template = @($configuration.build.template | ForEach-Object {
    if ($_ -in @('default', 'modern')) { $_ } else { Resolve-RepositoryPath $_ }
})
$configuration.build.output = $siteRoot
if ($configuration.build.ContainsKey('dest')) { $null = $configuration.build.Remove('dest') }
$configurationPath = Join-Path $workRoot 'docfx.json'
$configuration | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $configurationPath -Encoding utf8NoBOM
Write-Output $configurationPath

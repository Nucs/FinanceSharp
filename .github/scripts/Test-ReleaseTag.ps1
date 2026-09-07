# Release tags use vMAJOR.MINOR.PATCH with an optional SemVer prerelease.
# Build metadata (+...) is deliberately unsupported so package and tag versions match.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Tag,
    [ValidateNotNullOrEmpty()][string]$DefaultBranch = 'master'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param([string[]]$Arguments)
    $result = & git @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $($result -join ' ')" }
    return ($result -join "`n").Trim()
}

if ($Tag -cnotmatch '^v(?<version>(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-(?<prerelease>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?)$') {
    throw "Invalid release tag '$Tag'. Use vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-prerelease; build metadata is unsupported."
}
$version = $Matches.version
$prereleaseText = $Matches['prerelease']
$isPrerelease = -not [string]::IsNullOrEmpty($prereleaseText)
if ($isPrerelease) {
    foreach ($identifier in $prereleaseText.Split('.')) {
        if ($identifier -match '^0[0-9]+$') { throw "Numeric prerelease identifiers cannot have leading zeroes: '$identifier'." }
    }
}

$null = Invoke-Git -Arguments @('check-ref-format', "refs/remotes/origin/$DefaultBranch")
$tagCommit = Invoke-Git -Arguments @('rev-parse', '--verify', "refs/tags/$Tag^{commit}")
$headCommit = Invoke-Git -Arguments @('rev-parse', '--verify', 'HEAD^{commit}')
if ($tagCommit -ne $headCommit) { throw "Tag '$Tag' does not point to the checked-out HEAD." }
$branchCommit = Invoke-Git -Arguments @('rev-parse', '--verify', "refs/remotes/origin/$DefaultBranch^{commit}")
& git merge-base --is-ancestor $tagCommit $branchCommit
if ($LASTEXITCODE -ne 0) { throw "Release commit must belong to origin/$DefaultBranch. Fetch the complete repository history before validating." }

$prerelease = $isPrerelease.ToString().ToLowerInvariant()
if ($env:GITHUB_OUTPUT) {
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "version=$version`nprerelease=$prerelease" -Encoding utf8
}
Write-Host "Validated release $version (prerelease=$prerelease) at $tagCommit."

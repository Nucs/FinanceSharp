[CmdletBinding()]
param(
    [Alias('SiteDirectory')][string]$OutputDirectory = 'docs/_site',
    [switch]$Serve,
    [ValidateRange(1, 65535)][int]$Port = 8080
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$siteDirectory = [IO.Path]::GetFullPath($OutputDirectory, $repositoryRoot)
$relativeSite = [IO.Path]::GetRelativePath($repositoryRoot, $siteDirectory).Replace('\', '/')
if ($relativeSite -ne 'docs/_site' -and $relativeSite -notmatch '^artifacts/[^.][^:]*$') {
    throw 'OutputDirectory must be docs/_site or a directory below artifacts/.'
}

# Each build gets fresh metadata and site output. Publish the verified directory
# afterward so removed API pages cannot survive from an older build.
$runDirectory = Join-Path $repositoryRoot ('artifacts/docfx-build/' + [guid]::NewGuid().ToString('N'))
if ([IO.Path]::GetRelativePath($siteDirectory, $runDirectory) -notmatch '^\.\.') {
    throw 'OutputDirectory must not contain the temporary documentation build directory.'
}
$stagingSite = Join-Path $runDirectory 'site'
Push-Location -LiteralPath $repositoryRoot
try {
    dotnet tool restore
    if ($LASTEXITCODE -ne 0) { throw 'DocFX tool restore failed.' }
    $config = & "$repositoryRoot/docs/scripts/New-DocfxConfiguration.ps1" -SiteDirectory $stagingSite -WorkDirectory $runDirectory
    dotnet tool run docfx -- $config
    if ($LASTEXITCODE -ne 0) { throw "DocFX build failed. The previous site is unchanged; diagnostics are under $runDirectory." }
    & "$repositoryRoot/docs/scripts/Export-LlmDocs.ps1" -SiteDirectory $stagingSite
    & "$repositoryRoot/docs/scripts/Test-Documentation.ps1" -SiteDirectory $stagingSite

    if (Test-Path -LiteralPath $siteDirectory) {
        if (-not (Test-Path -LiteralPath (Join-Path $siteDirectory 'manifest.json') -PathType Leaf)) {
            throw "Refusing to replace a directory without a DocFX manifest: $siteDirectory"
        }
        # Both paths have been resolved and constrained to repository-generated
        # output. Keep the old site for diagnosis instead of deleting shared files.
        $backupSite = Join-Path $runDirectory 'previous-site'
        Move-Item -LiteralPath $siteDirectory -Destination $backupSite
    }
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $siteDirectory) -Force
    Move-Item -LiteralPath $stagingSite -Destination $siteDirectory
    Write-Host "Documentation built and verified: $siteDirectory"
    if ($Serve) {
        dotnet tool run docfx -- serve $siteDirectory --port $Port
        if ($LASTEXITCODE -ne 0) { throw 'DocFX preview server failed.' }
    }
} finally { Pop-Location }

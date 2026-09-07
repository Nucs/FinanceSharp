[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageDirectory)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$packageRoot = (Resolve-Path -LiteralPath $PackageDirectory).Path
& "$PSScriptRoot/Test-Package.ps1" -PackageDirectory $packageRoot -MetadataOnly
if ($LASTEXITCODE -ne 0) { throw 'Package validation failed.' }

$package = Get-ChildItem -LiteralPath $packageRoot -Filter 'FinanceSharp.*.nupkg' -File
$version = $package.BaseName.Substring('FinanceSharp.'.Length)
$assets = @(Get-ChildItem -LiteralPath $packageRoot -File | Where-Object Extension -in '.nupkg', '.snupkg')
$assets | Sort-Object Name | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $_.Name
} | Set-Content -LiteralPath (Join-Path $packageRoot 'SHA256SUMS') -Encoding utf8

$repositoryRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$notes = Join-Path $repositoryRoot "docs/releases/RELEASE_$version.md"
$curated = Test-Path -LiteralPath $notes -PathType Leaf
$body = @"
# FinanceSharp $version

Install this version:

    dotnet add package FinanceSharp --version $version

The release assets include the NuGet package, portable symbols, and SHA256SUMS.
"@
if ($curated) { $body += "`n`n" + (Get-Content -LiteralPath $notes -Raw) }
Set-Content -LiteralPath (Join-Path $packageRoot 'RELEASE_NOTES.md') -Value $body -Encoding utf8
if ($env:GITHUB_OUTPUT) {
    Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value "curated=$($curated.ToString().ToLowerInvariant())" -Encoding utf8
}
Write-Host "Prepared checksums and release notes for $version (curated=$curated). No publication performed."

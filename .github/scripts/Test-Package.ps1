[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PackageDirectory,
    [switch]$MetadataOnly,
    [switch]$RequireChecksums
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-ArchiveXml {
    param($Archive, [string]$Path)
    $entry = $Archive.GetEntry($Path)
    if ($null -eq $entry -or $entry.Length -eq 0) { throw "Missing or empty archive entry: $Path" }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { return [xml]$reader.ReadToEnd() } finally { $reader.Dispose() }
}

function Assert-ArchiveEntry {
    param($Archive, [string]$Path)
    $entry = $Archive.GetEntry($Path)
    if ($null -eq $entry -or $entry.Length -eq 0) { throw "Missing or empty archive entry: $Path" }
}

function Invoke-DotNet {
    param([string[]]$Arguments)
    & dotnet @Arguments
    if ($LASTEXITCODE -ne 0) { throw "dotnet $($Arguments -join ' ') failed with exit code $LASTEXITCODE." }
}

$packageRoot = (Resolve-Path -LiteralPath $PackageDirectory).Path
$packages = @(Get-ChildItem -LiteralPath $packageRoot -File -Filter 'FinanceSharp.*.nupkg')
$symbols = @(Get-ChildItem -LiteralPath $packageRoot -File -Filter 'FinanceSharp.*.snupkg')
if ($packages.Count -ne 1 -or $symbols.Count -ne 1) {
    throw 'Expected exactly one FinanceSharp .nupkg and one FinanceSharp .snupkg in PackageDirectory.'
}
if ($symbols[0].BaseName -cne $packages[0].BaseName) { throw 'Package and symbols filenames must have matching versions.' }

if ($RequireChecksums) {
    $checksums = @(Get-Content -LiteralPath (Join-Path $packageRoot 'SHA256SUMS'))
    foreach ($asset in @($packages[0], $symbols[0])) {
        $expected = (Get-FileHash -LiteralPath $asset.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $asset.Name
        if (@($checksums | Where-Object { $_ -ceq $expected }).Count -ne 1) { throw "Checksum missing or incorrect for $($asset.Name)." }
    }
}

$package = [IO.Compression.ZipFile]::OpenRead($packages[0].FullName)
$symbolPackage = $null
try {
    $symbolPackage = [IO.Compression.ZipFile]::OpenRead($symbols[0].FullName)
    $metadata = (Read-ArchiveXml $package 'FinanceSharp.nuspec').package.metadata
    $symbolMetadata = (Read-ArchiveXml $symbolPackage 'FinanceSharp.nuspec').package.metadata
    $version = [string]$metadata.version
    if ($metadata.id -cne 'FinanceSharp' -or [string]::IsNullOrWhiteSpace($version)) { throw 'Invalid package ID or version.' }
    if ($symbolMetadata.id -cne 'FinanceSharp' -or $symbolMetadata.version -cne $version) { throw 'Symbols metadata does not match the package.' }
    if ($packages[0].BaseName -cne "FinanceSharp.$version") { throw 'Package filename does not match its nuspec version.' }
    if ($metadata.repository.type -cne 'git' -or
        $metadata.repository.url -notmatch '^https://github\.com/Nucs/FinanceSharp(?:\.git)?/?$' -or
        $metadata.repository.commit -notmatch '^(?:[0-9a-f]{40}|[0-9a-f]{64})$') {
        throw 'Package must include its Git repository URL and full source commit.'
    }
    # NuGet omits the element when false, which is also the nuspec default.
    $licenseAcceptance = $metadata.SelectSingleNode("*[local-name()='requireLicenseAcceptance']")
    if ($null -ne $licenseAcceptance -and $licenseAcceptance.InnerText -cne 'false') { throw 'Package must not require license acceptance.' }
    if ($metadata.license.type -cne 'file' -or $metadata.license.InnerText -cne 'LICENSE' -or
        $metadata.readme -cne 'README.md' -or $metadata.icon -cne 'logo.png') {
        throw 'Package must declare LICENSE, README.md, and logo.png.'
    }
    foreach ($asset in @('LICENSE', 'README.md', 'logo.png')) { Assert-ArchiveEntry $package $asset }
    foreach ($framework in @('net8.0', 'net10.0')) {
        Assert-ArchiveEntry $package "lib/$framework/FinanceSharp.dll"
        $documentation = Read-ArchiveXml $package "lib/$framework/FinanceSharp.xml"
        if ($documentation.doc.assembly.name -cne 'FinanceSharp') { throw "Invalid XML documentation for $framework." }
        Assert-ArchiveEntry $symbolPackage "lib/$framework/FinanceSharp.pdb"
    }
} finally {
    $package.Dispose()
    if ($null -ne $symbolPackage) { $symbolPackage.Dispose() }
}

# An empty private package cache and exact source mapping ensure this tests the
# supplied artifact, even if the same version already exists locally or online.
if ($MetadataOnly) {
    Write-Host "Validated FinanceSharp $version package metadata, XML documentation, and symbols."
    exit 0
}
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$smokeRoot = Join-Path $tempRoot ("financesharp-package-" + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $smokeRoot
$succeeded = $false
try {
    $escapedFeed = [Security.SecurityElement]::Escape($packageRoot)
    $escapedVersion = [Security.SecurityElement]::Escape($version)
    @"
<configuration>
  <packageSources>
    <clear />
    <add key="local" value="$escapedFeed" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <fallbackPackageFolders><clear /></fallbackPackageFolders>
  <packageSourceMapping>
    <packageSource key="local"><package pattern="FinanceSharp" /></packageSource>
    <packageSource key="nuget.org"><package pattern="*" /></packageSource>
  </packageSourceMapping>
</configuration>
"@ | Set-Content -LiteralPath (Join-Path $smokeRoot 'NuGet.Config') -Encoding utf8
    @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFrameworks>net8.0;net10.0</TargetFrameworks>
    <PlatformTarget>x64</PlatformTarget>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup><PackageReference Include="FinanceSharp" Version="[$escapedVersion]" /></ItemGroup>
</Project>
"@ | Set-Content -LiteralPath (Join-Path $smokeRoot 'Consumer.csproj') -Encoding utf8
    '{"sdk":{"version":"10.0.100","rollForward":"latestFeature","allowPrerelease":false}}' |
        Set-Content -LiteralPath (Join-Path $smokeRoot 'global.json') -Encoding utf8
    @'
using System.Runtime.InteropServices;
using FinanceSharp;
using FinanceSharp.Indicators;

if (RuntimeInformation.ProcessArchitecture != Architecture.X64)
    throw new Exception("Package smoke test must run in an x64 process.");
var sma = new SimpleMovingAverage(3);
for (var i = 1; i <= 3; i++)
    sma.Update((long)i, new IndicatorValue(i));
var actual = (double)sma.Current.Value;
if (!sma.IsReady || actual != 2d)
    throw new Exception($"SMA(3): expected ready and 2, got ready={sma.IsReady}, value={actual}.");
Console.WriteLine($"{RuntimeInformation.FrameworkDescription}: package consumer passed (x64, SMA=2).");
'@ | Set-Content -LiteralPath (Join-Path $smokeRoot 'Program.cs') -Encoding utf8

    Push-Location -LiteralPath $smokeRoot
    try {
        $cache = Join-Path $smokeRoot 'packages'
        Invoke-DotNet -Arguments @('restore', 'Consumer.csproj', '--configfile', 'NuGet.Config', '--packages', $cache, '--no-http-cache', '--force')
        $hashPath = Join-Path $cache "financesharp/$($version.ToLowerInvariant())/financesharp.$($version.ToLowerInvariant()).nupkg.sha512"
        $expectedHash = [Convert]::ToBase64String([Security.Cryptography.SHA512]::HashData([IO.File]::ReadAllBytes($packages[0].FullName)))
        if ((Get-Content -LiteralPath $hashPath -Raw).Trim() -cne $expectedHash) { throw 'Restored package does not match the supplied artifact.' }
        Invoke-DotNet -Arguments @('build', 'Consumer.csproj', '--configuration', 'Release', '--no-restore')
        foreach ($framework in @('net8.0', 'net10.0')) {
            Invoke-DotNet -Arguments @('run', '--project', 'Consumer.csproj', '--configuration', 'Release', '--framework', $framework, '--no-build', '--no-restore')
        }
    } finally { Pop-Location }
    $succeeded = $true
} finally {
    if ($succeeded) {
        $resolvedSmoke = (Resolve-Path -LiteralPath $smokeRoot).Path
        $relative = [IO.Path]::GetRelativePath($tempRoot, $resolvedSmoke)
        if ($relative -notmatch '^financesharp-package-[0-9a-f]{32}$') { throw "Refusing cleanup outside the expected temp directory: $resolvedSmoke" }
        Remove-Item -LiteralPath $resolvedSmoke -Recurse -Force
    } else { Write-Warning "Package smoke files retained for diagnosis: $smokeRoot" }
}
Write-Host "Validated FinanceSharp $version package, symbols, metadata, and both consumer frameworks."

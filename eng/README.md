# Infrastructure and NumSharp parity

This records the second infrastructure audit against the local NumSharp checkout
at `a5084f0a9014341c5f163954197c203228715bbe`. All 13 jobs in its five workflows,
their invoked scripts, shared build settings, and repository conventions were reviewed.
Paths in the first column refer to NumSharp; the links refer to FinanceSharp.

| NumSharp infrastructure | FinanceSharp implementation or disposition |
| --- | --- |
| `build-and-release.yml`: `test` | [Build and Release](../.github/workflows/build-and-release.yml) tests .NET 8/10 on Windows, Linux, and Intel macOS and retains TRX files. No NumSharp-specific test exclusions are copied. |
| `verify-signing` | [Package verification](../.github/scripts/Test-Package.ps1) inspects real package metadata, both target DLL/XML pairs, symbols, README, icon, and license. NumSharp's Microsoft open signing key and friend-assembly identity are specific to its packages and are not adopted. |
| `interop-test` | No FinanceSharp Python.NET/OpenBLAS package, bundled runtime, or live NumPy parity suite exists. Native delivery/download scripts are not applicable. |
| `package-consumer-smoke` | The same built package is downloaded and installed into a fresh consumer/cache on Windows, Linux, and Intel macOS. Both .NET runtimes execute a moving-average calculation. Checksums verify artifact transfer; SHA512 confirms the installed package is the supplied artifact. |
| `validate-release` | [Tag validation](../.github/scripts/Test-ReleaseTag.ps1) checks SemVer, tag-to-HEAD identity, and remote default-branch ancestry. |
| `build-nuget` | One FinanceSharp package replaces NumSharp's five packages. Tags override the development version, with deterministic CI builds and Source Link. Package consumers run before publication. |
| `create-release` | [Release preparation](../.github/scripts/Prepare-Release.ps1) generates checksums and installation notes without publishing. It includes `docs/releases/RELEASE_<version>.md` when supplied; otherwise GitHub adds categorized generated notes. Both NuGet and symbols packages become release assets. |
| `publish-nuget` | Publication consumes the verified artifact, requires all managed/example/consumer gates, and is restricted to official-repository tag pushes. `ENABLE_NUGET_PUBLISH=true` and the protected `nuget` environment are required. Leave the variable unset while testing infrastructure. |
| `docs.yml`: `api-coverage` | NumSharp's NumPy API/oracle/benchmark inventories and `master-code-data` publication have no corresponding FinanceSharp subsystem. FinanceSharp instead verifies the actual generated public API and full documentation output. |
| `build-and-deploy` | [Documentation workflow](../.github/workflows/docs.yml) builds the complete site on PRs and branch pushes, uploads a preview, and deploys only from the official default branch through Pages/OIDC. |
| DocFX modern/custom templates, namespace overviews, source links/search/sitemap | [DocFX configuration](../docfx.json), FinanceSharp theme, API overwrites, and guides provide the adapted site. Generated YAML and site output remain ignored. |
| `generate-llms-txt.sh` | [Documentation scripts](../docs/scripts) export guides and generated API articles to `llms.txt` and `llms-full.txt`, plus robots and `.nojekyll`, using PowerShell 7 on each OS. |
| `fuzz-soak.yml`: `soak` | Its seeded NumPy corpus generator, differential replay, shrinker, and oracle do not exist in FinanceSharp. Introducing those would be new numerical-testing work, not a working infrastructure port. |
| `benchmark.yml`: `benchmark` | Its NumPy benchmark suite, generated dashboards, history/data branches, and post-release commits depend on a benchmark subsystem absent here. No empty or broken benchmark workflow is introduced. |
| `life-arcade.yml`: `windows` | The upgraded FinanceSharp Windows Forms example is built on both Windows target frameworks. Game-specific ZIP distribution, game tests, and issue forms are not applicable. |
| `global.json`, common MSBuild/package settings | Same stable .NET 10 SDK selection; deterministic builds, portable symbols, XML docs, explicit pack, embedded assets, and tag versions. Explicit TieredPGO/tiered compilation is unnecessary for a library targeting runtimes where these are defaults. |
| `.editorconfig`, `.gitattributes`, `.gitignore` | Adapted to FinanceSharp, with binary handling and generated-output rules. Existing source formatting is preserved. |
| Contributor guide, code of conduct, issue forms | Adapted for financial indicators, numeric reference outputs, and FinanceSharp's actual project paths and owner. |
| `FUNDING.yml`, `.git-blame-ignore-revs` | NumSharp's funding destination and mechanical-change commit IDs are repository-specific. Neither is copied. |
| Additional FinanceSharp infrastructure | CodeQL (including private-repository permissions), Dependabot for every maintained project/tool manifest, PR/security/maintenance guides, workflow linting, and checksum verification. |

FinanceSharp currently emits x64 assemblies, including under the AnyCPU project
configuration. Managed tests and installed-package consumers therefore run on
x64 hosts. Native AOT support and its supporting workflow, smoke project, and
documentation belong to separate pending development and are not included in
this infrastructure revision.

## Local commands

```sh
# Complete clean DocFX generation, exports, and validation; add -Serve to preview.
pwsh -File eng/Build-Docs.ps1

# Package release rehearsal. Use a new output directory; these commands never publish.
dotnet pack src/FinanceSharp/FinanceSharp.csproj -c Release -p:ContinuousIntegrationBuild=true -p:Version=0.0.0-ci --output artifacts/rehearsal
pwsh -File .github/scripts/Prepare-Release.ps1 -PackageDirectory artifacts/rehearsal
pwsh -File .github/scripts/Test-Package.ps1 -PackageDirectory artifacts/rehearsal -RequireChecksums

# Windows example compilation.
dotnet build examples/FinanceSharp.Examples/FinanceSharp.Examples.csproj -c Release

```

The maintained [workflow](../.github/workflows/build-and-release.yml) checks all
workflow YAML with pinned, checksum-verified actionlint 1.7.12. When changing this
pin, update the download URL and checksum together from its upstream release.
Build/test commands and repository settings are in [MAINTAINING.md](../MAINTAINING.md).

## Later PR validation

Keep `ENABLE_NUGET_PUBLISH` unset. A feature branch/PR exercises workflow linting,
managed tests, packages/consumers, the Windows example, documentation, and CodeQL.
None of these PR jobs publish a NuGet package.
Check every matrix result and download the documentation/package/TRX artifacts.
Tag-validation tests and local release preparation can be rehearsed without a
remote tag. Hosted permissions, Pages OIDC, and macOS runtime behavior still need
actual GitHub runs; a successful Windows rehearsal is not a hosted-run result.

The example build currently reports `NU1903` for DotNetZip 1.16.0
([GHSA-xhg6-9j5j-w4vf](https://github.com/advisories/GHSA-xhg6-9j5j-w4vf)). Its replacement
belongs with the concurrent example upgrade; the infrastructure does not suppress
that warning or change the example's dependencies.

# Maintaining FinanceSharp

The infrastructure follows NumSharp's build/test/release and DocFX approach, adapted to FinanceSharp's projects. The [complete parity audit](eng/README.md) maps all 13 NumSharp workflow jobs and their supporting conventions. CI does not need the reference submodule, Python, NumSharp's benchmarks, or its signing key.

## Local validation

Install the x64 .NET 8 and .NET 10 SDKs and PowerShell 7 (`pwsh`). `global.json` selects a stable .NET 10 SDK, accepting later .NET 10 feature bands. From the repository root:

```sh
dotnet restore tests/FinanceSharp.Tests/FinanceSharp.Tests.csproj
dotnet build tests/FinanceSharp.Tests/FinanceSharp.Tests.csproj -c Release --no-restore
dotnet test tests/FinanceSharp.Tests/FinanceSharp.Tests.csproj -c Release -f net8.0 --no-build
dotnet test tests/FinanceSharp.Tests/FinanceSharp.Tests.csproj -c Release -f net10.0 --no-build
dotnet pack src/FinanceSharp/FinanceSharp.csproj -c Release --output artifacts/nuget
pwsh -File .github/scripts/Prepare-Release.ps1 -PackageDirectory artifacts/nuget
pwsh -File .github/scripts/Test-Package.ps1 -PackageDirectory artifacts/nuget -RequireChecksums
pwsh -File eng/Build-Docs.ps1
```

Use an empty package output directory for each version. The package checker rejects ambiguous output, verifies package assets, and restores/runs a consumer on both frameworks from the local feed with a fresh package cache. It needs access to nuget.org for dependencies. `artifacts/`, generated API YAML, and `docs/_site/` are ignored.

`Directory.Build.props` enables deterministic builds, XML documentation, portable debug output, and the SDK's CI behavior on GitHub Actions. `Directory.Build.targets` centralizes the library's packaging policy: explicit packing, symbols packages, an embedded README, and repository metadata. It is imported after the project because the legacy project defines conflicting package-on-build settings. The project remains the source of the local development version; a release overrides `Version` from its tag. The .NET SDK includes Source Link for GitHub. The existing license, copyright, and package icon are preserved.

## GitHub workflows

| Workflow | Validation | Publication |
| --- | --- | --- |
| Build and Release | Workflow lint; .NET 8/10 tests and installed-package consumers on Windows/Linux/Intel macOS; Windows example builds | Valid `v*` tag pushes in `Nucs/FinanceSharp`, after all gates pass and publishing is explicitly enabled |
| Documentation | Clean DocFX API/articles build, local links/fragments, source/search checks and full text exports on every PR and branch push; downloadable preview | GitHub Pages on the default branch of `Nucs/FinanceSharp` |
| CodeQL | Manual build and C# analysis on PRs, branch pushes, and weekly | Code scanning results |

The managed test matrix uses `macos-15-intel` because FinanceSharp currently produces x64 assemblies, including under its AnyCPU configuration. Consumers need an x64 process. The solution includes a Windows Forms example, so cross-platform automation targets the library/test projects directly. Existing NUnit skips are respected; no test category exclusions are added. Source XML documentation warnings remain visible while comments are improved; missing-comment warnings (`CS1591`) alone are suppressed.

Native AOT support, its smoke project, workflow, and documentation are separate pending development. This infrastructure revision does not claim Native AOT compatibility or require Native AOT checks for releases.

PR builds use read-only contents access and do not receive publishing secrets. Publication permissions are scoped to the jobs that need them. Forks can run validation, but repository guards prevent them from publishing under FinanceSharp's identity. Dependabot checks GitHub Actions, the library, tests, Windows example, and local tool manifest weekly. Action references are pinned to commits and can be updated by Dependabot.

## One-time repository setup

Before the first deployment or release, configure these settings in GitHub and NuGet:

1. Enable GitHub Actions. Under **Settings → Pages**, choose **GitHub Actions** as the build source. The site URL is `https://nucs.github.io/FinanceSharp/`. Restrict the `github-pages` environment to the default branch.
2. Keep the repository variable **ENABLE_NUGET_PUBLISH** unset while validating infrastructure. For a separately authorized release, set it to `true`, create the **nuget** environment, and add **NUGET_API_KEY**, scoped to publishing FinanceSharp on nuget.org. Confirm package ownership. Restrict the environment to release tags and add required reviewers if the project needs a release approval step.
3. Enable Code scanning for the checked-in CodeQL workflow; avoid also enabling a duplicate default CodeQL setup. Enable Dependabot alerts, security updates, and private vulnerability reporting. Code scanning for a private repository may require GitHub Code Security; it is available for public repositories.
4. Add a default-branch ruleset requiring PR review and the workflow lint, managed tests, package/consumer matrix, Windows example, documentation build, and CodeQL checks after their first run. Protect release tags from replacement/deletion. Use the actual check names GitHub records; workflows intentionally do not use path filters that would leave required checks pending.
5. Review tracked files and repository history for material that cannot be made public, including credentials, third-party test datasets, and the legacy binary files under `libs/`. Preserve existing upstream copyright/license notices and record any redistribution requirements before making the repository public.

This checkout prepares the configuration; these account settings and repository visibility are not changed by a local build. The [security policy](SECURITY.md) explains the reporting fallback until private vulnerability reporting is enabled.

## Releasing

Use tags of the form `v1.2.3` or `v1.2.3-rc.1`. The validator accepts three numeric components without leading zeroes, and optional SemVer prerelease identifiers; build metadata (`+...`) is intentionally not accepted. The tag must point at the checked-out commit, and that commit must be reachable from the remote default branch.

1. Merge the release changes and version bump through a PR. The local version lives in `src/FinanceSharp/FinanceSharp.csproj`; coordinate that edit with whoever owns source changes. Run the validation commands above.
2. Create and push the annotated release tag from the merged commit. For example, after confirming the intended version and commit:

   ```sh
   git tag -a v1.2.3 -m "FinanceSharp 1.2.3"
   git push origin v1.2.3
   ```

3. The tag workflow checks its format and ancestry, runs managed tests and Windows example builds, and builds the `.nupkg` and `.snupkg` with `-p:Version=1.2.3`. Consumers on all three OSes verify and run the same package artifact.
4. With `ENABLE_NUGET_PUBLISH=true`, the `nuget` environment publishes the verified package and symbols, then creates the GitHub release with both packages and `SHA256SUMS`. Add optional authored notes at `docs/releases/RELEASE_1.2.3.md`; otherwise categorized GitHub notes are generated using `.github/release.yml`. Installation instructions are included either way. A tag containing a prerelease suffix creates a prerelease on GitHub.
5. Check the installed NuGet package, symbols, release assets, and generated notes. A failed publishing job can be rerun: NuGet skips an already published version and existing release assets are refreshed. Never move a published tag or reuse its version for different bytes; correct it in a new version.

Ordinary pushes, PRs, and manual workflow runs validate without publishing packages. The publishing job also stays disabled when `ENABLE_NUGET_PUBLISH` is unset. NuGet publication is irreversible; enabling publishing and pushing a release tag is a separate maintainer action. Documentation is published independently from the default branch.

## Infrastructure references

- [NumSharp reference infrastructure](https://github.com/SciSharp/NumSharp/tree/master/.github/workflows)
- [GitHub runner labels and architectures](https://github.com/actions/runner-images#available-images)
- [.NET SDK Source Link support](https://learn.microsoft.com/en-us/dotnet/core/compatibility/sdk/8.0/source-link)
- [DocFX documentation](https://dotnet.github.io/docfx/)
- [GitHub Pages deployment workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)

# Contributing to FinanceSharp

Contributions to the library, tests, documentation, and build infrastructure are welcome. Please follow the [Code of Conduct](CODE_OF_CONDUCT.md) and use the [security policy](SECURITY.md) for vulnerability reports.

## Getting started

Install Git and the x64 .NET 8 and .NET 10 SDKs. The library and test project target `net8.0` and `net10.0`; running both test targets requires both runtimes. Run these commands from the repository root:

```sh
dotnet restore tests/FinanceSharp.Tests/FinanceSharp.Tests.csproj
dotnet build src/FinanceSharp/FinanceSharp.csproj -c Release --no-restore
dotnet test tests/FinanceSharp.Tests/FinanceSharp.Tests.csproj -c Release -f net8.0 --no-restore
dotnet test tests/FinanceSharp.Tests/FinanceSharp.Tests.csproj -c Release -f net10.0 --no-restore
```

Use these project paths for library development. The solution also contains a Windows Forms example targeting .NET 8/10 for Windows; CI builds it on Windows. The `refs/NumSharp` submodule is reference material and is not needed to build or test FinanceSharp.

To run a focused test while developing, add a filter, for example:

```sh
dotnet test tests/FinanceSharp.Tests/FinanceSharp.Tests.csproj -c Release -f net10.0 --filter FullyQualifiedName~DelayTests
```

## Finding your way around

| Area | Location |
| --- | --- |
| Indicators and consolidators | [src/FinanceSharp/Indicators](src/FinanceSharp/Indicators) |
| Array and market data types | [src/FinanceSharp/Data](src/FinanceSharp/Data) |
| Indicator composition | [src/FinanceSharp/Graphing](src/FinanceSharp/Graphing) |
| Unit tests | [tests/FinanceSharp.Tests](tests/FinanceSharp.Tests) |
| Reference test data | [tests/FinanceSharp.Tests/TestData](tests/FinanceSharp.Tests/TestData) |
| Documentation configuration | [docfx.json](docfx.json) |

## Making a change

Open an issue before a substantial API change or new subsystem so its intended behavior can be discussed. Keep pull requests focused, follow the style of nearby code and the existing editor configuration, and avoid unrelated formatting or dependency changes.

For a bug report, include a minimal C# reproduction, the FinanceSharp version or commit, .NET version, operating system, and expected and actual results. Remove credentials and private or licensed market data before sharing a reproduction.

For changes to numerical behavior:

- Include a small, deterministic input series and independently justified expected values. Cite the formula or the version and output of a reference implementation when applicable.
- State the indicator parameters, timestamps, input and output shapes, and floating-point tolerance. Explain changes to an existing tolerance.
- Test relevant warm-up, `IsReady`, `Samples`, reset, and repeated-update behavior. Cover empty input, invalid parameters, non-finite values, or timestamp boundaries when affected by the change.
- Preserve tests that demonstrate existing behavior unless the pull request explains why that behavior should change. Call out any compatibility impact on callers.
- For performance changes, provide a reproducible measurement and check that results remain correct.

Tests use NUnit. Add regression tests near the affected tests and run both target frameworks before requesting review. Documentation-only changes need a documentation build; report any checks you could not run and why.

## Building documentation

DocFX is a repository-local .NET tool. From the repository root:

```sh
pwsh -File eng/Build-Docs.ps1
```

Install PowerShell 7 (`pwsh`) and use `pwsh -File eng/Build-Docs.ps1 -Serve` to preview the generated site. The script restores the pinned DocFX tool, generates fresh API pages and guides, exports text documentation, and checks links, fragments, search, and source links. Update the relevant Markdown and XML API comments when changing public behavior. Commit documentation sources and assets; leave generated output out of the pull request.

## Submitting a pull request

Create a branch from `master`, describe the problem and resulting behavior, and link the related issue when one exists. Include the commands you ran and their results. For API changes, include a short caller example and migration guidance where needed.

Preserve existing copyright and attribution notices, including notices on code derived from QuantConnect/Lean. Identify the origin of any imported code or data and ensure it can be distributed with this project. See [LICENSE](LICENSE) for the repository's license.

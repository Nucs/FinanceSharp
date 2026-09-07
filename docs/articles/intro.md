# Getting started

FinanceSharp provides technical indicators, data consolidators, and graph connections
for processing sequences of financial data. The current library targets .NET 8 and
.NET 10. FinanceSharp assemblies target x64, so consuming applications must run in
an x64 process.

## Build from source

Install the .NET 10 SDK and clone the repository. From its root, build the library:

```sh
dotnet restore src/FinanceSharp/FinanceSharp.csproj
dotnet build src/FinanceSharp/FinanceSharp.csproj --configuration Release --framework net10.0 -p:Platform=x64 --no-restore
```

The project also targets `net8.0`; use `--framework net8.0` to build that target.
Run .NET 8 applications with the .NET 8 runtime installed.

To try the following example, create a console project in a sibling directory and
add a project reference to `src/FinanceSharp/FinanceSharp.csproj`. Target `net8.0` or
`net10.0` and set `<PlatformTarget>x64</PlatformTarget>` in the console project's
property group.

## Calculate a moving average

Feed values to an indicator in timestamp order. The timestamp and value are separate
arguments; timestamps use Unix milliseconds in UTC.

```csharp
using System;
using FinanceSharp.Indicators;

var average = new SimpleMovingAverage(period: 3);
long start = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
double[] prices = [10.0, 20.0, 30.0, 40.0];

for (int i = 0; i < prices.Length; i++)
{
    average.Update(start + i * 60_000L, prices[i]);

    if (average.IsReady)
    {
        Console.WriteLine(average.Current.Value);
    }
}
// 20
// 30
```

<xref:FinanceSharp.Indicators.SimpleMovingAverage> becomes ready after its configured
period of updates. Other indicators have their own warm-up requirements; check
`IsReady` before using an output that requires a complete window.

## The data model

<xref:FinanceSharp.DoubleArray> represents data with shape `(Count, Properties)`.
`Count` is the number of items; `Properties` is the number of `double` values in
each item. Scalar indicator inputs and outputs have one property. Structured market
data uses multiple properties per item.

Use `DoubleArray.From` to wrap a scalar, managed array, or supported unmanaged
structure. Array overloads that accept `copy` let you choose between copying the
input and sharing its storage. Inspect the relevant overload and the concrete array
type before relying on buffer ownership or lifetime.

Indicators expose their latest output through `Current`, its timestamp through
`CurrentTime`, and update notifications through `Updated`. Consolidators aggregate
input data, and graph extensions connect their outputs to other computation stages.

## Explore further

- [API reference](../api/index.md): public types and their XML documentation.
- [Examples in the repository](https://github.com/Nucs/FinanceSharp/tree/master/examples):
  additional graph and plotting examples with their own dependencies.
- [Contribution guide](https://github.com/Nucs/FinanceSharp/blob/master/CONTRIBUTING.md):
  development workflow and pull request expectations.

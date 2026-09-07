---
title: FinanceSharp
_layout: landing
---

<section class="fs-intro">
  <p class="fs-kicker">Technical analysis for .NET</p>
  <h1>FinanceSharp</h1>
  <p class="fs-lead">Build connected computations from technical indicators,
  market data consolidators, and a common array model.</p>
  <div class="fs-actions">
    <a class="fs-primary" href="articles/intro.md">Get started</a>
    <a href="api/index.md">Explore the API</a>
    <a href="https://github.com/Nucs/FinanceSharp">View source</a>
  </div>
  <p>For .NET 8 and .NET 10 on x64. APIs are under active development;
  this reference is generated from the current source.</p>
</section>

<div class="fs-cards">
  <a class="fs-card" href="articles/intro.md">
    <strong>Your first indicator</strong>
    <span>Calculate a moving average and understand timestamped inputs and array shapes.</span>
  </a>
  <a class="fs-card" href="api/index.md">
    <strong>API reference</strong>
    <span>Search generated type and member documentation, signatures, and source links.</span>
  </a>
  <a class="fs-card" href="articles/documentation.md">
    <strong>Help improve the docs</strong>
    <span>Build the complete site, validate links, and contribute guides or API descriptions.</span>
  </a>
</div>

## A first indicator

```csharp
using FinanceSharp.Indicators;

var average = new SimpleMovingAverage(period: 3);
average.Update(1_700_000_000_000L, 10.0);
average.Update(1_700_000_060_000L, 20.0);
average.Update(1_700_000_120_000L, 30.0);

Console.WriteLine(average.IsReady);        // True
Console.WriteLine(average.Current.Value); // 20
```

Times are Unix timestamps in milliseconds. See the
[getting started guide](articles/intro.md) for project setup and how to supply data.

## Documentation exports

The complete build also provides `llms.txt`, a documentation index, and
`llms-full.txt`, all guides and API articles as text, alongside the searchable site.

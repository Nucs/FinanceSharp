---
uid: FinanceSharp.Indicators
summary: Technical analysis indicators, their common base classes, and indicator composition.
remarks: |
  Start with <xref:FinanceSharp.Indicators.SimpleMovingAverage> for a windowed
  indicator. <xref:FinanceSharp.Indicators.IndicatorBase> exposes timestamped updates,
  current output, readiness, reset behavior, and update events.

  Feed observations in timestamp order and inspect `IsReady` before consuming
  an output that requires a complete warm-up window. Each indicator documents
  its parameters and warm-up behavior in its API page.
---

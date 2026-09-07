---
uid: FinanceSharp
summary: Core FinanceSharp data types, array storage, market data structures, time conversion, and update contracts.
remarks: |
  Use this namespace for the data passed between computation stages.

  - <xref:FinanceSharp.DoubleArray> represents values with shape `(Count, Properties)`.
  - <xref:FinanceSharp.IndicatorValue> represents a scalar indicator value.
  - <xref:FinanceSharp.BarValue> and <xref:FinanceSharp.TradeBarValue> represent market bars.
  - <xref:FinanceSharp.IUpdatable> is the common contract for receiving timestamped data.

  Array wrappers differ in storage ownership and lifetime. Read the selected
  constructor or `DoubleArray.From` overload before sharing buffers between stages.
---

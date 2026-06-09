# FinanceToolkit Composite Scorecard

Add a `get_composite_scorecard()` method to the `Toolkit` controller that ranks each company-period observation with a peer-quartile composite scorecard built from existing model and ratio outputs.

## Task

The method collects four higher-is-better metrics for the toolkit's tickers and reshapes them into a `(ticker, period)` panel:

- the Piotroski F-Score and the Altman Z-Score (available from the `models` controller),
- the gross margin and the asset turnover ratio (available from the `ratios` controller).

Use the existing controller methods to obtain these — do not re-derive them from raw statements. Each metric is a per-ticker, per-period value; an observation is one `(ticker, period)` pair.

Score each metric independently across only the observations that have a finite value for it: with `b` peers strictly below the observation's value and `n` finite peers in total, `pr = b / (n - 1)` maps to 0 points for `pr < 0.25`, 1 for `pr < 0.50`, 2 for `pr < 0.75`, and 3 for `pr >= 0.75`; if an observation is the sole holder of a metric it scores 3 for it.

The composite is the weighted sum of those points using weights F-Score 0.40, Z-Score 0.30, gross margin 0.15, asset turnover 0.15, proportionally renormalized to sum to 1 over the metrics present for that observation. A metric that is missing or non-finite for an observation is dropped from that observation's weighting (never treated as zero). Round the composite to the toolkit's configured rounding.

## Return value

Return a `pandas.DataFrame`:

- indexed by `(ticker, period)` with index names `["ticker", "period"]`,
- with columns, in order: `Composite Score`, `F-Score Points`, `Z-Score Points`, `Gross Margin Points`, `Asset Turnover Points`,
- a points column holds `NaN` where that metric is absent for the observation,
- rows sorted best to worst by `Composite Score` descending, breaking ties by `F-Score Points` descending (a missing F-Score sorts last), then ticker ascending, then period descending.

## Constraints

- Reuse the existing `models` and `ratios` controller outputs; no new data fetching or network calls.
- Output must be deterministic.
- Implement only the method; do not author or modify any test files.

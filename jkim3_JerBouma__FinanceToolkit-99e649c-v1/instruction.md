# FinanceToolkit Composite Ranking Scorecard

Implement a peer-relative composite ranking in a new module `financetoolkit/composite_scorecard.py` with the signature `compute_composite_ranking(metrics) -> dict`.

The input maps each ticker to a dict containing any subset of four higher-is-better metrics: `f_score`, `z_prime`, `gross_margin`, `asset_turnover`. Metrics are provided as pre-computed values — the module performs no data fetching and makes no network calls.

Score each metric independently across only the stocks that have a finite value for it: let `b` be the count of peers strictly less than the stock's value and `pr = b / (n - 1)`, where `n` is the number of stocks having that metric; award 0 points for `pr < 0.25`, 1 for `pr < 0.50`, 2 for `pr < 0.75`, else 3. If a stock is the sole holder of a metric it scores 3 for it.

The composite is the weighted sum of points using weights f_score 0.40, z_prime 0.30, gross_margin 0.15, asset_turnover 0.15, proportionally renormalized to sum to 1 over the metrics that stock actually has.

Any value that is missing, `None`, or non-finite (NaN/Inf) is treated as absent: drop it from that stock's weighting and breakdown, and exclude it from every other stock's peer computation for that metric. Never raise for such values. A stock that ends up with no usable metrics is not ranked.

Ordering must be fully deterministic, including when composites tie.

## Return value

Return a dict with these exact keys:

- `ranking`: list of tickers from best to worst.
- `scores`: mapping from each ranked ticker to a dict with `composite` (the renormalized weighted point-sum), `metrics` (the metric values actually used), `tier_points` (per-metric points), `weights_applied` (the renormalized weights), and `excluded_metrics` (sorted list of the metrics dropped for that stock). Excluded metrics must be absent from `metrics` and `tier_points` rather than present with a null value.
- `excluded_stocks`: list of `{"ticker": ..., "reason": ...}` for stocks with no usable metrics.

Raise `ValueError` when `metrics` is empty.

## Constraints

- No network calls, no data fetching — metrics are provided as input.
- Output must be deterministic.
- Implement only the module; do not author or modify any test files.

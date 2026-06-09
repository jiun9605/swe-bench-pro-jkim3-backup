# FinanceToolkit Composite Ranking Scorecard

Implement a new module in FinanceToolkit that computes a composite ranking scorecard for a set of stocks using peer-quartile tiered scoring.

## Context

This module implements a composite ranking scorecard using peer-quartile tiered scoring. Metrics are provided as pre-computed values — no data fetching, no network calls.

## Task

Create `financetoolkit/composite_scorecard.py` and expose it via `financetoolkit/__init__.py`.

### Public API

```python
def compute_composite_ranking(
    metrics: dict[str, dict[str, float]],
) -> dict:
    ...
```

The function takes pre-computed metrics per ticker, buckets each by peer quartile, applies the weighted point-sum with renormalization for missing metrics, and returns the ranked scorecard.

Input `metrics` format:
```python
{
    "AAPL": {"f_score": 7.0, "z_prime": 3.41, "gross_margin": 0.52, "asset_turnover": 0.9},
    "MSFT": {"f_score": 8.0, "z_prime": 4.2,  "gross_margin": 0.68, "asset_turnover": 0.7},
    ...
}
```

### Metrics (all higher-is-better)

| Metric | Description | Range |
|--------|-------------|-------|
| f_score | Piotroski F-Score | 0–9 |
| z_prime | Altman Z'-Score (private-firm variant) | typically 0–5+ |
| gross_margin | (Revenue − COGS) / Revenue | 0–1 |
| asset_turnover | Revenue / Total Assets | 0–2+ |

### Aggregation — peer-quartile tiered scorecard

For each metric independently, over only the peer stocks that have a finite value for it:

```
b_i  = count of peers with value strictly < value_i
pr_i = b_i / (n_metric - 1)          # n_metric = peers having this metric
points_i = 0 if pr_i < 0.25
           1 if 0.25 <= pr_i < 0.50
           2 if 0.50 <= pr_i < 0.75
           3 if pr_i >= 0.75
```

Equal values → equal pr → equal points (this is how composite ties arise → tie-break fires).

**Edge:** if `n_metric == 1`, that lone stock gets `points = 3`.

**Weights:** `{f_score: 0.40, z_prime: 0.30, gross_margin: 0.15, asset_turnover: 0.15}`

```
composite_i = Σ_m  w'_m · points_{i,m}      # over metrics present for stock i
```
where `w'` = the stock's weights proportionally renormalized to sum to 1 after dropping any missing metric.

### Missing-metric handling (report_card precedent)

- Stock missing metric m: omit m from `tier_points` and `metrics` (key absent, never None); list it under `excluded_metrics`; renormalize that stock's weights over the remaining metrics; and exclude that stock's value from every other stock's peer quartile calc for m.
- Stock missing all four metrics → not ranked; appears in top-level `excluded_stocks` with a reason.

### Tie-breaking (deterministic)

Sort key = `(composite desc, f_score desc, ticker asc)`

If a tied stock is itself missing f_score, treat its f_score as -1 for ordering only.

### Output contract

```python
{
  "ranking": ["AAA", "BBB", ...],            # best -> worst
  "scores": {
    "AAA": {
      "composite": 2.55,                      # reweighted weighted point-sum
      "metrics": {
        "f_score": 7.0,
        "z_prime": 3.41,
        "gross_margin": 0.52,
        "asset_turnover": 0.9
      },
      "tier_points": {
        "f_score": 3,
        "z_prime": 2,
        "gross_margin": 3,
        "asset_turnover": 1
      },
      "weights_applied": {
        "f_score": 0.40,
        "z_prime": 0.30,
        "gross_margin": 0.15,
        "asset_turnover": 0.15
      },
      "excluded_metrics": []
    },
    ...
  },
  "excluded_stocks": [
    {"ticker": "ZZZ", "reason": "no usable metrics"}
  ]
}
```

Keys for excluded metrics are absent from `metrics`/`tier_points`, present in `excluded_metrics`, and `weights_applied` reflects the renormalized weights.

### Error conditions (ValueError)

- `metrics` empty
- Any metric value is not a finite number (NaN or Inf) — treat as missing, don't raise
- After filtering missing metrics, a ticker has no usable metrics → excluded, not raised

### Edge cases the tests pin

- One stock missing gross_margin → excluded from that metric's peer calc, reweighted
- One stock with NaN values → treated as missing for those metrics
- Deliberate tie in composite → resolved by f_score, then ticker

### Constraints

- No network calls, no data fetching — metrics are provided as input
- Deterministic output — exact equality or tight atol (1e-9)
- Do NOT modify instruction.md, tests, or invent ranking rules — implement exactly the specified contract
- Keep existing tests green

## Tests

New tests in `tests/test_composite_scorecard.py` will FAIL at base_commit (module absent) and PASS after your implementation. They assert exact ranking order, composite values (atol 1e-9), every tier_points value, exclusion keys, and each edge row.

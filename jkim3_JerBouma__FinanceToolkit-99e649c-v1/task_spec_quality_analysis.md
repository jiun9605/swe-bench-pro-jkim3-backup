# Task Spec Quality Analysis — FinanceToolkit Composite Scorecard

Base commit: `99e649ccd1f49614b6f4023f151bf2d783111943` (JerBouma/FinanceToolkit)
Verified: baseline → 5/5 FAIL ("Module not implemented yet"); gold solution → 5/5 PASS;
container oracle / sonnet / opus all 3/3.

## Defining characteristic

This is a **synthetic, self-contained feature**, not a change derived from a real PR.
The new module (`financetoolkit/composite_scorecard.py`) imports only `math`, references
no FinanceToolkit internals, and is not wired into `__init__.py` or any controller. The
scoring algorithm (peer-quartile tiers, the specific weights, the renormalization rule) is
**invented for this task** and has no precedent in the repository. Consequence: almost
nothing the candidate needs can be inferred from the codebase, so the spec must (and does)
state essentially the entire algorithm. This makes the task well-specified but low-difficulty
and decoupled from repository knowledge.

## Missing / Non-inferable Information

| # | Description | Inferable from Codebase? | Explanation |
|---|-------------|--------------------------|-------------|
| 1 | The four metrics and that all are higher-is-better | No | Invented for the task; no precedent. Spec provides it. |
| 2 | Tier thresholds (pr < .25 → 0, < .50 → 1, < .75 → 2, else 3) and `pr = b/(n-1)` with `b` = strictly-less count | No | Arbitrary algorithm; cannot be derived. Required for exact composite values. Spec provides it. |
| 3 | Weights `{f_score .40, z_prime .30, gross_margin .15, asset_turnover .15}` | No | Arbitrary; required to reproduce composite = 2.55. Spec provides it. |
| 4 | Weight renormalization over present metrics (sum to 1) | No | Required; test pins `f_score weight == 0.4/0.85`. Spec provides it. |
| 5 | `n_metric == 1` → points = 3 edge | No | Arbitrary edge; not directly asserted but affects results. Spec provides it. |
| 6 | NaN / Inf / None treated as missing (not error) | Partial | NaN handling is tested; "treat as missing" is a reasonable default but the no-raise behavior is non-obvious. Spec provides it. |
| 7 | Tie-break key `(composite desc, f_score desc, ticker asc)`; missing f_score → −1 for ordering | No | Required for deterministic order; test pins AAA before EEE. Spec provides it. |
| 8 | Output dict shape: `ranking`, `scores[ticker].{composite,metrics,tier_points,weights_applied,excluded_metrics}`, `excluded_stocks` | No | Exact keys are asserted by tests; cannot be inferred. Spec provides it. |
| 9 | Excluded metric keys absent (never `None`) from `metrics`/`tier_points` | No | Tested (`"gross_margin" not in ...`). Spec provides it. |
| 10 | Empty input raises `ValueError`; message need only contain "empty" | Partial | Raise-on-empty is conventional; exact wording is NOT pinned (test uses `match="empty"`). Spec provides it. |

**Net:** every necessary item is already in the spec. The task is **not under-specified**.

## Quality Issues Found

1. **Hint / test-scenario leakage.** The "### Edge cases the tests pin" section (missing
   gross_margin, NaN stock, deliberate tie) discloses the exact test scenarios, and asides
   like "this is how composite ties arise → tie-break fires" coach the candidate. For an
   interview question these should be removed.

2. **Phantom precedent.** "Missing-metric handling (report_card precedent)" cites a
   `report_card` pattern that does not exist in the codebase — misleading.

3. **Over-specification vs. tests.** Several stated behaviors are not validated by any test:
   Inf handling, the `n_metric == 1 → 3` edge value, the exact `excluded_stocks` reason text,
   and the full ranking order (only `ranking[0]` and the tie pair are checked). A candidate
   could implement these differently and still pass.

4. **Decoupled from the codebase (design-level).** Standalone module, no imports, not wired
   in. As a repository-knowledge interview question it tests none. Empirically easy (both
   frontier models 3/3).

## Notes on tests and patch

- **Tests:** representative and, after relaxing the error-message regex to `match="empty"`,
  not overly strict. Mild leniency: full ranking order is not asserted beyond the first
  element and the tie pair; only BBB's composite is pinned.
- **Patch:** clean, minimal, pure-stdlib, correct against the spec. No excess scope.

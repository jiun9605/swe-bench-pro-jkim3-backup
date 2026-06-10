# FinanceToolkit Composite Scorecard — Task

Feature-addition task on JerBouma/FinanceToolkit, pinned to base commit
`99e649ccd1f49614b6f4023f151bf2d783111943`. The solver adds a
`get_composite_scorecard()` method to the `Toolkit` controller
(`financetoolkit/toolkit_controller.py`) that ranks each `(ticker, period)`
observation with a peer-quartile composite scorecard.

The method reuses existing controller outputs — the Piotroski F-Score and Altman
Z-Score from `models`, and the gross margin and asset turnover ratio from
`ratios` — reshapes them into a `(ticker, period)` panel, tiers each metric 0-3
by peer quartile, renormalizes weights over present metrics, and returns a sorted
`pandas.DataFrame`. This couples the task to the real codebase: the solver must
discover and call four controller methods, extract the `Piotroski Score` /
`Altman Z-Score` MultiIndex rows, align the panel, handle real-data NaNs, and
assemble the DataFrame.

## Files

- `instruction.md` — task spec (return contract with exact columns/index; tie-break stated).
- `solution/solve.sh` — oracle: applies the gold patch (the method) to `/app`.
- `tests/config.json` — grading contract (patch, test_patch, fail_to_pass, pass_to_pass, ...).
- `tests/test_composite_scorecard.py` — gold tests (delivered via `test_patch`).
- `tests/{test.sh,run_script.sh,parser.py}` — verifier entrypoint, runner, output parser.
- `environment/Dockerfile` — python:3.12-slim + uv; clones repo, syncs deps, resets to base.

## Tests

- fail_to_pass (7): `tests/test_composite_scorecard.py::` test_scorecard_structure,
  test_scorecard_ranking_order, test_scorecard_composite_values,
  test_scorecard_tier_points_and_quartiles, test_scorecard_missing_metric_handling,
  test_scorecard_growth_shape_and_values, test_scorecard_growth_zero_base_edge.
  Build a `Toolkit` from the repo's recorded statement pickles
  (`tests/datasets/*.pickle`, offline) and assert DataFrame shape, column order,
  full ranking order, exact composite values, tier points (all quartiles 0-3
  exercised), NaN/renormalization handling for missing metrics, and the `growth=True`
  period-over-period composite growth (incl. the divide-by-zero edge where a prior
  composite is 0).
- pass_to_pass (12): `tests/models/test_piotroski_model.py::*` — pre-existing repo
  tests as a regression guard that also exercises the real package build.

All tests run through the real package via `uv run --frozen pytest` from `/app`.

## Model Analysis

`codimango bench run` per agent on the leak-fixed task (commit `04998fd`). These are the
**trustworthy** numbers: an earlier test bug let `build_toolkit()` fetch `^TNX` over the
network, which fails in the hermetic grader and made results flaky — so the pre-fix numbers
(below, in history) were network noise, not difficulty. Post-fix the tests run fully offline
(verified: 19/19 with the network namespace blocked, twice; deterministic).

| Agent | Model | Attempts | Pass rate | Failure nature |
|-------|-------|----------|-----------|----------------|
| oracle | oracle | 3 | 3/3 | — (gold patch; deterministic; 19/19 each) |
| metacode | meta/avocado_dvsc_tester | 5 | 4/5 | 1 genuine wrong-answer: dropped incomplete (NaN-bearing) observations so shape was (6,5) not (8,5), treated a missing metric as 0 instead of NaN, and mishandled the growth zero-base (inf) edge |
| claude-code | claude-sonnet-4-6 | 3 | _pending clean re-run_ | — |
| claude-code | claude-opus-4-8 | 3 | _pending clean re-run_ | — |

Difficulty: `medium`. The task requires real multi-controller API navigation + pandas
reshaping. On the stable (offline) base, the avocado failure is a legitimate correctness
error on the subtle parts of the contract — which observations to include, missing-metric =
NaN-not-zero, and the growth edge cases — confirming the task discriminates on correctness.
Platform measures difficulty empirically.

## Notes / history

This task was **redesigned** from an earlier standalone `financetoolkit/composite_scorecard.py`
module (`compute_composite_ranking(metrics) -> dict`) that took pre-computed metrics. That
version was well-formed and passed every solver (oracle 3/3, sonnet 3/3, opus 3/3, avocado
5/5), but it was stdlib-only and decoupled from the codebase — it tested generic Python rather
than repository knowledge, and was too easy to be approvable. It was re-anchored to the real
`Toolkit`/`Models`/`Ratios` controllers so the solver must navigate actual APIs and DataFrame
shapes; tests now import and drive the real package against recorded statement pickles (no
hardcoded import paths, no homemade runner).

Harness hardening retained from the original: `tests/test.sh` resets all fail_to_pass /
pass_to_pass test files to gold before applying `test_patch`, so an agent that writes its own
tests cannot corrupt grading; `run_script.sh` isolates each test's cwd in a subshell.

**Leak fix (`04998fd`).** The first codebase-coupled version had a flaky test: `build_toolkit()`
omitted `_daily_risk_free_rate` / `_daily_treasury_data`, so the toolkit fetched `^TNX` via
yfinance — which fails in the hermetic grader and poisoned the yfinance session cache, making
the 7 composite tests pass-alone / fail-together. This failed Eval-GT (`gt_resolved=0`, all 7
fail_to_pass tests failing) and made the pre-fix model runs (oracle 6/6, opus 5/6, sonnet 2/6,
avocado 9/10 with timeouts) **network noise rather than a difficulty signal**. The fix seeds
both attributes from the shipped pickles in `build_toolkit()` (mirroring the repo's own
`test_models_controller.py` / `test_toolkit_controller.py`), making the suite fully offline and
deterministic. The Model Analysis table above reflects the post-fix, trustworthy numbers.

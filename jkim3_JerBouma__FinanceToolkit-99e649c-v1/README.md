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

- fail_to_pass (5): `tests/test_composite_scorecard.py::` test_scorecard_structure,
  test_scorecard_ranking_order, test_scorecard_composite_values,
  test_scorecard_tier_points_and_quartiles, test_scorecard_missing_metric_handling.
  Build a `Toolkit` from the repo's recorded statement pickles
  (`tests/datasets/*.pickle`, offline) and assert DataFrame shape, column order,
  full ranking order, exact composite values, tier points (all quartiles 0-3
  exercised), and NaN/renormalization handling for missing metrics.
- pass_to_pass (12): `tests/models/test_piotroski_model.py::*` — pre-existing repo
  tests as a regression guard that also exercises the real package build.

All tests run through the real package via `uv run --frozen pytest` from `/app`.

## Model Analysis

`codimango bench run` on the redesigned (codebase-coupled) task, pooled across runs:

| Agent | Model | Attempts | Pass rate | Failure nature |
|-------|-------|----------|-----------|----------------|
| oracle | oracle | 6 | 6/6 | — (gold patch; deterministic) |
| metacode | meta/avocado_dvsc_tester | 10 | 9/10 | 1 genuine wrong-answer: treated a missing Z-Score as 0 points instead of dropping it and renormalizing, which mis-ranked the top observation |
| claude-code | claude-opus-4-8 | 6 | 5/6 | timeout / agent-exit on the longer convergence |
| claude-code | claude-sonnet-4-6 | 6 | 2/6 | mostly AgentTimeoutError — actively working (~47 tool calls/trial) but did not converge in budget |

Difficulty: `medium`. The redesign moved the task from a self-contained algorithm
(all solvers 3/3) to real multi-controller API navigation + pandas reshaping. Failures
are a mix of one genuine correctness bug (avocado's renormalization-vs-zero handling of a
missing metric) and convergence-time timeouts (sonnet); the agent timeout was raised to
2700s to let the signal reflect correctness rather than clock speed. Platform measures
difficulty empirically.

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

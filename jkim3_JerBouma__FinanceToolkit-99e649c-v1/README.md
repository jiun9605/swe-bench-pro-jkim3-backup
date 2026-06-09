# FinanceToolkit Composite Ranking Scorecard — Task

Feature-addition task on JerBouma/FinanceToolkit, pinned to base commit
`99e649ccd1f49614b6f4023f151bf2d783111943`. The solver implements a new standalone module
`financetoolkit/composite_scorecard.py` exposing `compute_composite_ranking(metrics) -> dict`,
which ranks stocks with a peer-quartile tiered scorecard over four pre-computed,
higher-is-better metrics (`f_score`, `z_prime`, `gross_margin`, `asset_turnover`). No data
fetching, no network — metrics are passed in.

## Files

- `instruction.md` — task spec (return contract with exact keys; tie-break precedence stated).
- `solution/solve.sh` — oracle: applies the gold module patch under `/app`.
- `tests/config.json` — grading contract (patch, test_patch, fail_to_pass, pass_to_pass, ...).
- `tests/test_composite_scorecard.py` — gold tests (delivered via `test_patch`).
- `tests/{test.sh,run_script.sh,parser.py}` — verifier entrypoint, runner, output parser.
- `environment/Dockerfile` — python:3.12-slim + uv; clones repo, syncs deps, resets to base.
- `task_spec_quality_analysis.md` — review notes from `/review-task`.

## Tests

- fail_to_pass (5): `tests/test_composite_scorecard.py::` test_composite_ranking_basic,
  test_missing_metric_exclusion, test_tie_breaking, test_nan_handling, test_error_conditions.
  Assert exact composite (2.55), tier_points, renormalized weights (0.4/0.85),
  excluded-metric absence, sole-holder->3, deterministic tie-break, NaN/None as missing,
  ValueError on empty, and non-empty exclusion reason.
- pass_to_pass (12): `tests/models/test_piotroski_model.py::*` — pre-existing repo tests
  (Piotroski F-Score domain) as a regression guard that also exercises the real package
  build via `uv run --frozen pytest`.

## Model Analysis

Local `codimango bench run` results after spec/harness fixes:

| Agent | Model | Attempts | Pass rate | Notes |
|-------|-------|----------|-----------|-------|
| oracle | oracle | 3 | 3/3 | Gold patch; deterministic. |
| claude-code | claude-sonnet-4-6 | 3 | 3/3 | Clean solve. |
| claude-code | claude-opus-4-8 | 3 | 3/3 | Clean solve. |
| metacode | meta/avocado_dvsc_tester | 5 | 0/5 (invalid) | Not a task signal — agent failed to install/run locally (AgentInstallError / NonZeroAgentExitCodeError); agent never produced a solution, so only the 12 pass_to_pass passed. Re-run needs a working metacode dist (--mount/--metacode-version). |

Difficulty: easy. Every working solver passes 3/3; `task.toml` is set to `difficulty = "easy"`.

## Notes / history

Earlier spurious failures were diagnosed and fixed, not difficulty: an agent-created test file
collided with `test_patch` apply (hardened `tests/test.sh` to reset test paths to gold first);
a brittle exact-error-message assertion (relaxed to `match="empty"`); a `run_script.sh` cwd
leak between tests (subshell-isolated); and a missing tie-break precedence in the spec
(restored). The module is intentionally self-contained (stdlib only), graded by importing it
directly from `/app`.

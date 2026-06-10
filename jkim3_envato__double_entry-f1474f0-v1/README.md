# jkim3_envato__double_entry-f1474f0-v1

Rolling 24-hour per-account withdrawal limit for the [envato/double_entry](https://github.com/envato/double_entry)
Ruby double-entry bookkeeping library.

- **Repo / base commit:** `envato/double_entry` @ `f1474f0fe160edadd3b3264397b85d38d3a7751d` (Release 2.0.2)
- **Language / framework:** Ruby 3.3, RSpec, ActiveRecord (SQLite at test time)
- **Category:** Feature Implementation (original — not derived from any issue/PR/commit)

## Description

The task asks the agent to add an optional **rolling 24-hour DYNAMIC withdrawal
limit** to an account. When an account is configured with a
`withdrawal_limit_ratio` (a number like `0.5`; `nil` = unlimited, the default), a
cross-entity transfer **out** of that account must be rejected if its gross
cross-entity outflow over the trailing 24 hours, plus the current transfer, would
exceed a **dynamic cap** = `ratio × time-weighted average balance over the
window` (floored to cents). Violations raise a new
`DoubleEntry::WithdrawalLimitExceeded` and must write no lines.

Two things carry the difficulty:
- **Time-weighted average balance.** The cap is not `ratio × current balance`
  and not `ratio × mean(per-line balances)` — it is the time integral of the
  balance trajectory over the window divided by its length. The solver must
  reconstruct the trajectory from the balance carried into the window plus each
  in-window line's stored running `balance`, weighting each level by how long it
  was held. A balance held half the window contributes half; a deposit not yet
  held grants ~0 capacity; an account with no history has a zero cap.
- **Cross-entity gross outflow.** Consumption counts only cross-entity **debits**
  (partner in another `scope`). Same-entity moves never consume the cap (and a
  same-entity transfer is not checked) — but they DO change the real balance, so
  they shift the average-balance term. Deposits do not offset outflow; they raise
  capacity only through the average. This forces the solver into both the
  `partner_scope` column and the per-line `balance` column.

It tests at once: account-attribute plumbing (`Set#define → Account.new →
Account::Instance` via `delegate`); the ledger model (`Line.amount` sign,
`partner_scope`, per-line `balance`); a time-weighted integral over a
reconstructed trajectory; the inclusive boundary; and — the crux —
**concurrency correctness**: the read must run **inside the
`Locking.lock_accounts` block in `Transfer#process`, before any line is
written**.

A naive approach fails because it is easy to (a) use current or mean balance
instead of the time-weighted integral, (b) sum `Line.debits` and ignore
`partner_scope` (counts internal moves), (c) double-count deposits (offset
outflow AND raise the cap), (d) check the current same-entity transfer, (e)
mishandle the inclusive boundary or the floor, or (f) put the check outside the
lock. The test suite pins each of these.

## Completion Rates

`k=5` unless noted. Oracle and the no-fix baseline are verified; frontier/Avocado
calibration is run during the calibration pass.

| Agent | Pass rate |
|-------|-----------|
| Oracle | _TBD — re-run after dynamic-cap rebuild_ |
| No-fix baseline (no patch) | **0** (verified locally — 9 `fail_to_pass` fail, 1 `pass_to_pass` happy-path passes on the new spec) |
| Sonnet 4.6 (`claude-code`) | _TBD — recalibration pass_ |
| Opus 4.8 (`claude-code`) | _TBD — recalibration pass_ |
| Avocado (`metacode`, `meta/avocado_dvsc_tester`) | _TBD — target: pass ≥1 and fail ≥1 of 5 (was 5/5 on the flat net cross-entity version → rebuilt as a dynamic time-weighted cap)_ |

> **Note:** the task was rebuilt twice — flat gross-outflow → flat net
> cross-entity (Avocado still 5/5, solved by one query) → **dynamic cap = ratio ×
> time-weighted average balance**. The dynamic version forces a time integral
> over a reconstructed balance trajectory, which a single aggregation query can't
> express. All numbers above must be re-measured; local reference run is 65/65
> across the 5 selected spec files (3 random seeds), base 9-fail/1-pass.

## Model Analysis

_To be completed during the recalibration pass. For each model: trials
passed/failed, the specific failure in each failing trial, then the dominant
failure modes across all models and why they reflect reasoning gaps (not
task-setup issues)._

Expected dominant failure modes (hypotheses to confirm against trajectories):
- **Current/mean balance instead of time-weighted** — using `ratio ×
  current_balance` or averaging per-line balances ⇒ fails the time-weighted-cap,
  cap-grows-with-hold-time, deposit-not-yet-held, and same-entity-lowers-cap
  examples. This is the headline trap.
- **Ignoring `partner_scope`** — summing `Line.debits` without excluding
  same-entity partners ⇒ counts internal moves, fails same-entity-withdrawal.
- **Double-counting deposits** — letting deposits offset outflow AND raise the cap.
- **Checking same-entity transfers** — applying the cap to an internal move.
- **Wrong floor / boundary** — `>=` vs `>`, or rounding instead of floor.
- **Partial write on violation** — writing a line before raising ⇒ fails
  "writes no lines".
- **Check placed outside the lock** — may still pass these single-threaded specs;
  watch for it in trajectory review even when green.

> If any failure traces to a flaky test, missing dependency, or ambiguous spec,
> that is a task-setup defect — fix the task before submitting, do not record it
> as a model reasoning gap.

## Anti-Cheating Analysis

- **Hardcoded outputs:** tests assert observable behavior — a raised error class,
  persisted vs. absent `Line` rows, and recomputed `Money` balances (e.g.
  `change { wallet.balance }.by(Money.new(-60_00))`). There are no magic output
  strings to echo.
- **Overfitting to visible tests:** `pass_to_pass` carries 12 existing-repo
  regressions (transfer/account/balance_calculator/line specs) plus a below-limit
  happy-path invariant. An over-restrictive solution that rejects legitimate
  sub-limit withdrawals fails the invariant; a solution that breaks the ledger
  fails the regressions — neither is predictable from the `fail_to_pass` set alone.
- **Modifying test files:** `test.sh` resets every `fail_to_pass`/`pass_to_pass`
  file to its gold state (restore-if-tracked, remove-if-untracked) and re-applies
  `test_patch` itself before running — any agent edits to spec files are discarded.
  The agent's solution lives only in `lib/` (in `patch`), never in the spec paths.
- **Bypassing the intended path:** the limit is enforced in `Transfer#process`
  inside the lock, and the tests drive real `DoubleEntry.transfer` calls, asserting
  ledger side effects (lines + balances). There is no output artifact to fake;
  passing requires exercising the patched transfer/line code path.

## Notes for the author (not part of submission)

- `instruction.md` is intentionally a **human TODO placeholder** — see
  `SPEC_CONTRACT.md` and write the prompt by hand (no LLM tokens in the prompt).
- After writing `instruction.md`, run `/review-task` and address findings, then
  run the calibration pass and fill the tables above.

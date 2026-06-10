# jkim3_envato__double_entry-f1474f0-v1

Rolling 24-hour per-account withdrawal limit for the [envato/double_entry](https://github.com/envato/double_entry)
Ruby double-entry bookkeeping library.

- **Repo / base commit:** `envato/double_entry` @ `f1474f0fe160edadd3b3264397b85d38d3a7751d` (Release 2.0.2)
- **Language / framework:** Ruby 3.3, RSpec, ActiveRecord (SQLite at test time)
- **Category:** Feature Implementation (original — not derived from any issue/PR/commit)

## Description

The task asks the agent to add an optional **rolling 24-hour net withdrawal
limit** to an account. When an account is configured with a
`daily_withdrawal_limit` (a `Money` value; `nil` = unlimited, the default), a
transfer **out** of that account must be rejected if its **net cross-entity
outflow** over the trailing 24 hours, plus the current transfer, would exceed the
limit. Violations raise a new `DoubleEntry::WithdrawalLimitExceeded` and must
write no lines.

"Net cross-entity" carries the difficulty:
- **Cross-entity only.** Only flows whose partner is a *different* entity (a
  different `scope`) count. Moves between two of the same entity's own accounts
  (same scope) are internal — they never consume the limit, and a same-entity
  transfer is not checked at all. This forces the solver into the `Line`
  `partner_scope` column, not just a `Line.debits` sum.
- **Net of deposits.** Cross-entity deposits offset cross-entity withdrawals
  one-for-one, with **no floor** — having paid in more than taken out lets an
  entity withdraw that surplus on top of the limit (deposit 1000 ⇒ withdraw
  1000 + limit).
- **Trailing window.** Offsetting deposits age out of the 24h window, shrinking a
  previously-available allowance.

It tests several things at once: DoubleEntry's account-attribute plumbing
(`Set#define → Account.new → Account::Instance` via `delegate`); the ledger model
(`Line.amount` sign + `partner_scope` to separate cross-entity from internal
flow); time-windowed net aggregation; the inclusive boundary; and — the crux —
**concurrency correctness**: the check must run **inside the
`Locking.lock_accounts` block in `Transfer#process`, before any line is
written**, so concurrent transfers cannot race past the cap.

A naive approach fails because it is easy to (a) sum `Line.debits` and ignore
`partner_scope` (counts internal moves, fails same-entity examples), (b) ignore
credits (fails deposit-offset / banking), (c) check the current same-entity
transfer against the cap, (d) mishandle the inclusive boundary, or (e) put the
check outside the lock. The test suite pins each of these.

## Completion Rates

`k=5` unless noted. Oracle and the no-fix baseline are verified; frontier/Avocado
calibration is run during the calibration pass.

| Agent | Pass rate |
|-------|-----------|
| Oracle | _TBD — re-run after net/cross-entity rebuild_ |
| No-fix baseline (no patch) | **0** (verified — 9 `fail_to_pass` fail, 13 `pass_to_pass` pass; local: 9 fail / 1 pass on new spec) |
| Sonnet 4.6 (`claude-code`) | _TBD — recalibration pass_ |
| Opus 4.8 (`claude-code`) | _TBD — recalibration pass_ |
| Avocado (`metacode`, `meta/avocado_dvsc_tester`) | _TBD — target: pass ≥1 and fail ≥1 of 5 (was 5/5 on the simpler outflow-only version → rebuilt as net/cross-entity)_ |

> **Note:** the task was rebuilt from a simple gross-outflow limit (Avocado 5/5,
> too easy) to a **net cross-entity** limit. All numbers above must be
> re-measured; the local reference run is 65/65 across the 5 selected spec files.

## Model Analysis

_To be completed during the recalibration pass. For each model: trials
passed/failed, the specific failure in each failing trial, then the dominant
failure modes across all models and why they reflect reasoning gaps (not
task-setup issues)._

Expected dominant failure modes (hypotheses to confirm against trajectories):
- **Ignoring `partner_scope`** — summing `Line.debits` for the account without
  excluding same-entity partners ⇒ counts internal moves, fails the
  same-entity-withdrawal and same-entity-deposit examples.
- **Ignoring credits** — counting only outflow, not net ⇒ fails the deposit-offset
  / banking example.
- **Checking same-entity transfers** — applying the cap to the current internal
  transfer ⇒ rejects a same-entity move that should be exempt.
- **Clamping net at zero** — flooring net outflow ⇒ fails the "withdraw surplus on
  top of limit" banking assertion.
- **Wrong window / no expiry** — all-time aggregation ⇒ fails window-expiry and the
  offsetting-deposit-ages-out example.
- **Boundary off-by-one** — `>=` instead of `>` ⇒ fails the inclusive-boundary
  example.
- **Partial write on violation** — writing a line before raising ⇒ fails the
  "writes no lines" assertion.
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

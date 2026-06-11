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

`k=5` unless noted. **Pass rate = reward over trials that ran to completion**;
trials that died with `AgentTimeoutError` / `NonZeroAgentExitCodeError` are
infrastructure failures (agent crash/timeout), not reasoning failures, and are
excluded from the difficulty signal per AAI policy.

| Agent | Raw reward | Completed-trial pass rate | Notes |
|-------|-----------|---------------------------|-------|
| Oracle | 3/3 = 1.000 | 3/3 | verified, no flakiness |
| No-fix baseline (no patch) | 0 | 0 | 9 `fail_to_pass` fail, 13 `pass_to_pass` pass (incl. happy-path) |
| Sonnet 4.6 (`claude-code`) | 4/5 = 0.800 | **4/4** | the 1 zero-reward trial was `NonZeroAgentExitCodeError` (crash), not a test fail |
| Opus 4.8 (`claude-code`) | 2/5 = 0.400 | **2/5** | clean run, `err=0` — 3 genuine reasoning failures (see below) |
| Avocado (`metacode`) | 3/5 = 0.600 | **3/3** | the 2 zero-reward trials were `NonZeroAgentExitCodeError` (crash); 2 passing trials also logged `AgentTimeoutError` |

> **Calibration caveat (timeouts).** The 2026-06-10 16:52 runs hit ~50 min against
> the old `agent.timeout_sec = 3000`; several trials timed out or crashed near the
> limit, inflating the raw zero-reward counts for Avocado/Sonnet. `agent.timeout_sec`
> has been raised to **5400** (verifier 3600) to remove this; rerun for clean raw
> numbers. The completed-trial column is the trustworthy signal until then.

> **Build history.** flat gross-outflow → flat net cross-entity (Avocado 5/5,
> solved by one query) → **dynamic cap = ratio × time-weighted average balance**.
> The dynamic version forces a time integral over a reconstructed balance
> trajectory. Local reference run: 65/65 across the 5 selected spec files (3 random
> seeds); base (no solution) 9-fail / 1-pass.

## Model Analysis

Calibration pass 2026-06-10 16:52 (`k=5`, jobs `…d6b0fd` Avocado, `…40f68b` Opus,
`…bd93a0` Sonnet). Trajectories and verifier output inspected per failing trial.

### Opus 4.8 — 2/5 (clean, `err=0`) — genuine reasoning failures
All 3 zero-reward trials (`5Ms5a9k`, `ShYWm9i`, `LefSqNg`) share one signature:
**13 required pass (incl. the below-cap happy-path), all 9 enforcement
`fail_to_pass` fail** — i.e. the limit never fired and every withdrawal was
allowed. Root cause (confirmed in trajectory): Opus set `@withdrawal_limit_ratio`
and the `attr_reader` on `Account` but **did not add `withdrawal_limit_ratio` to
the `delegate … to: :account` list on `Account::Instance`**. Because
`Transfer#process` operates on an `Account::Instance`, `from_account
.withdrawal_limit_ratio` returned `nil` → `return unless ratio` → enforcement
skipped entirely. This is a real codebase-comprehension gap (the
Account → Instance delegation plumbing), exactly what the task is designed to
test — not a task-setup defect (oracle is 3/3 and other agents pass, so the tests
are not false-negative).

### Sonnet 4.6 — 4/4 completed (4/5 raw)
Every trial that ran to completion passed with a correct time-weighted, cross-
entity-filtered solution. The single zero-reward trial (`GxTSstJ`) died with
`NonZeroAgentExitCodeError` (agent crash) — **infrastructure, not a reasoning
gap**; excluded from the difficulty signal.

### Avocado (`metacode`) — 3/3 completed (3/5 raw)
The 2 zero-reward trials (`7Q5Qeau`, `8pH8wQS`) died with
`NonZeroAgentExitCodeError`; 2 of the passing trials also logged
`AgentTimeoutError` (brushing the 3000s limit). **All zero-reward outcomes are
infra (crash/timeout), not reasoning.** Avocado solves the feature correctly when
it completes.

### Dominant reasoning-gap (the discriminating failure)
- **Missing `Account::Instance` delegation** — read the ratio on `Account` but not
  reachable from the instance the transfer uses ⇒ limit silently never enforced
  (Opus, 3 trials). The headline gap this task catches.

Other traps the suite pins (watch for in future trajectories):
- **Current/mean balance instead of time-weighted** ⇒ fails time-weighted-cap,
  cap-grows-with-hold-time, deposit-not-yet-held, same-entity-lowers-cap.
- **Ignoring `partner_scope`** ⇒ counts internal moves.
- **Double-counting deposits** (offset outflow AND raise the cap).
- **Wrong floor / boundary** (`>=` vs `>`, round vs floor).
- **Partial write on violation** ⇒ fails "writes no lines".

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

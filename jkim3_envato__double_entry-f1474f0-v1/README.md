# jkim3_envato__double_entry-f1474f0-v1

Rolling 24-hour per-account withdrawal limit for the [envato/double_entry](https://github.com/envato/double_entry)
Ruby double-entry bookkeeping library.

- **Repo / base commit:** `envato/double_entry` @ `f1474f0fe160edadd3b3264397b85d38d3a7751d` (Release 2.0.2)
- **Language / framework:** Ruby 3.3, RSpec, ActiveRecord (SQLite at test time)
- **Category:** Feature Implementation (original — not derived from any issue/PR/commit)

## Description

The task asks the agent to add an optional **rolling 24-hour net withdrawal limit**
to an account. When an account is configured with a `daily_withdrawal_limit` (a
`Money` value in the account's currency; `nil` = unlimited, the default), a transfer
**out** of that account must be rejected when it would push the account's **net
cross-entity outflow over the trailing 24 hours** above the limit. Violations raise a
new `DoubleEntry::WithdrawalLimitExceeded` and must write no lines (balances
unchanged).

Two things carry the difficulty:
- **Net cross-entity accounting.** The limit counts only money that crosses to a
  *different* entity — lines whose partner is in another `scope`. Moves between two
  accounts of the same entity (same scope) are internal: they neither consume the
  limit nor, when the current transfer is itself internal, trigger the check at all.
  Within the window, cross-entity deposits offset cross-entity withdrawals
  one-for-one, with **no floor** — an entity that has received more than it has sent
  may withdraw that surplus on top of the limit. The solver must reach into both the
  `partner_scope` column and the `Line.amount` sign, not just sum debits.
- **Trailing window + atomicity.** Only lines with `created_at` in the trailing 24h
  count, so both prior withdrawals and offsetting deposits age out over time. And the
  windowed read must run **inside the `Locking.lock_accounts` block in
  `Transfer#process`, before any line is written**, so concurrent transfers cannot
  race past the cap.

It tests at once: account-attribute plumbing (`Set#define → Account.new →
Account::Instance` via `delegate`); the ledger model (`Line.amount` sign,
`partner_scope`, `scope`, `created_at`); the net-of-deposits / no-floor semantics;
the inclusive boundary (a transfer landing exactly on the remaining allowance is
allowed); and placement of the check inside the transfer lock.

A naive approach fails because it is easy to (a) sum `Line.debits` and ignore
`partner_scope` (counts internal moves), (b) ignore deposits or clamp net at zero
(breaks the offset / no-floor cases), (c) check or consume the limit on a same-entity
transfer, (d) mishandle the inclusive boundary, (e) forget to delegate
`daily_withdrawal_limit` to `Account::Instance` (the limit then never fires), or (f)
write a partial line set on violation. The test suite pins each of these.

## Completion Rates

Latest validation cohort — **2026-06-11 14:27**, against HEAD `2f9d375` (after the
agent timeout was raised to 5400s / verifier 3600s, which cleared the earlier infra
crashes and near-limit timeouts, so these are clean reasoning numbers). `k=5` for
agents, `k=3` for oracle.

| Agent / model | Pass rate | Job |
|---------------|-----------|-----|
| Oracle | 3/3 (100%) | `bd46057a` |
| Opus 4.6 (`claude-code`) | 5/5 (100%) | `f24e9495` |
| GPT-5.5 (`codex`) | 5/5 (100%) | `040057c2` |
| Avocado (`metacode`) | 4/5 (80%) | `894726a1` |
| No-fix baseline (no patch) | 0/5 | 9 `fail_to_pass` fail, 13 `pass_to_pass` pass (incl. below-limit happy path) |

> The immediately prior cohort (13:54, commit `2b1ab33`) was 5/5 across Oracle,
> Opus, GPT-5.5 and Avocado, so Avocado's single miss in the latest cohort looks
> nondeterministic rather than a stable difficulty signal. Earlier 2026-06-10
> cohorts (commits `0f009c0`…`8473ac6`) showed widespread 0/5 results, but those ran
> against in-flux task files — the `test-patch-validation` job itself failed at
> several of those SHAs — so they are not a model signal.
>
> Local reference run: 65/65 across the 5 selected spec files (3 random seeds);
> base (no solution) 9-fail / 13-pass.

## Model Analysis

Latest cohort (2026-06-11 14:27, HEAD `2f9d375`). The shipped feature is the **flat
net cross-entity 24h limit** (`daily_withdrawal_limit`, a `Money` value).

### Oracle — 3/3
Reference solution stable, no flakiness.

### Opus 4.6 (`claude-code`) — 5/5 · GPT-5.5 (`codex`) — 5/5
Both frontier agents solved the feature cleanly on every trial.

### Avocado (`metacode`) — 4/5
One trial failed. Per-trial verifier output could not be retrieved — the Codimango
trials endpoint was returning HTTP 500 for every job at the time of writing — so the
root cause is unconfirmed. The prior cohort had Avocado at 5/5 on the same task, so
treat this as a likely nondeterministic miss and re-run to confirm before recording
it as a reasoning gap.

### Traps the suite pins (for future trajectories)
- **Missing `Account::Instance` delegation** of `daily_withdrawal_limit` — read on
  `Account` but not reachable from the instance `Transfer#process` uses ⇒ the limit
  silently never fires (all 9 enforcement `fail_to_pass` fail while the 13 required
  pass). The headline codebase-comprehension gap this task catches.
- **Ignoring `partner_scope`** ⇒ counts same-entity (internal) moves toward the limit.
- **No deposit offset / clamping net at zero** ⇒ fails the net-of-deposits and
  no-floor examples.
- **Wrong boundary** (`>=` vs `>`) on the inclusive remaining-allowance check.
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

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

Latest validation cohort — **2026-06-11 14:27**, against HEAD `2f9d375` (after
`agent.timeout_sec` was raised to 5400 / verifier 3600, which cleared the earlier
infra crashes and near-limit timeouts). `k=5` for agents, `k=3` for oracle. This is
the **dynamic** version of the task (`withdrawal_limit_ratio` × time-weighted average
balance).

| Agent / model | Pass rate | Job |
|---------------|-----------|-----|
| Oracle | 3/3 (100%) | `bd46057a` |
| Opus 4.6 (`claude-code`) | 5/5 (100%) | `f24e9495` |
| GPT-5.5 (`codex`) | 5/5 (100%) | `040057c2` |
| Avocado (`metacode`) | 4/5 (80%) | `894726a1` |
| No-fix baseline (no patch) | 0/5 | 9 enforcement `fail_to_pass` fail, 13 `pass_to_pass` pass (incl. within-cap happy path) |

> The prior cohort (13:54, commit `2b1ab33`) was 5/5 across Oracle, Opus, GPT-5.5 and
> Avocado. Avocado's single miss in the latest cohort was a **non-attempt** — the
> agent read the repo and stopped after ~4.8k output tokens without writing a
> solution (all enforcement tests fail, only the pre-existing regressions pass), i.e.
> an early agent termination, not a reasoning failure. Re-run to confirm.
>
> Local reference run: 65/65 across the 5 selected spec files (3 random seeds); base
> (no solution) 9-fail / 13-pass.

> **Difficulty caveat.** Frontier agents (Opus 4.6, GPT-5.5) now pass this dynamic
> task 5/5, so the live discriminating signal is weak. An earlier calibration pass
> (2026-06-10, Opus 4.8) saw 2/5 with genuine reasoning failures (the delegation gap
> below); the current frontier models clear it.

> **Build history.** flat gross-outflow → flat net cross-entity (Avocado 5/5, solved
> by one query) → **dynamic cap = ratio × time-weighted average balance**. The dynamic
> version forces a time integral over a reconstructed balance trajectory.

## Model Analysis

Latest cohort (2026-06-11 18:01, HEAD `2f9d375`). Raw counts include
infrastructure failures (rate-limit / crash / install); the trustworthy signal is
the **completed-trial** rate after excluding those per AAI policy.

### Oracle — 3/3
Reference solution stable, no flakiness.

### Avocado (`metacode`) — 5/5
Solves the dynamic feature cleanly on every trial (legit). Earlier cohorts showed
Avocado zeros that were all infra — a 0-byte `metacode-bin` download
(`AgentInstallError`) and `NonZeroAgentExitCodeError`/`AgentTimeoutError` near the
old 3000s limit — never reasoning failures.

### GPT-5.5 (`codex`) — failures are infra (OpenAI rate limit)
Zero-reward `codex` trials are **not** solve attempts: the agent turn fails with
`Rate limit reached for gpt-5.5 … tokens-per-min (TPM): Limit 40000000, Used
40000000` after 5 reconnect retries, so no `lib/` change is written and the verifier
runs against the unmodified repo (the `13 pass / 9 fail` no-solution signature).
Excluded from the difficulty signal; `codex` is also not a target calibration agent.

### Opus 4.x (`claude-code`) — the discriminating failure
Opus is the one frontier agent that fails on *reasoning*, not infra. Across cohorts
its clean (`err=0`) zero-reward trials share one signature: **13 required pass (incl.
the within-cap happy path), all 9 enforcement `fail_to_pass` fail** — the limit never
fires (see below). The 2026-06-10 cohort had Opus 4.8 at 2/5 with this signature on
every failing trial.

### The discriminating failure (historical — 2026-06-10, Opus 4.8, 2/5)
Opus 4.8 failed 3/5 with one signature: **13 required pass (incl. the within-cap happy
path), all 9 enforcement `fail_to_pass` fail** — the limit never fired. Root cause
(trajectory-confirmed): it set `@withdrawal_limit_ratio` and the `attr_reader` on
`Account` but **did not add `withdrawal_limit_ratio` to the `delegate … to: :account`
list on `Account::Instance`**. Since `Transfer#process` works with an
`Account::Instance`, `from_account.withdrawal_limit_ratio` returned `nil` → `return
unless ratio` → enforcement skipped entirely. A real Account→Instance
delegation-plumbing gap, exactly what the task targets (oracle 3/3 and other agents
pass, so the tests are not false-negative).

### Other traps the suite pins
- **Current/mean balance instead of time-weighted** ⇒ fails time-weighted-cap,
  cap-grows-with-hold-time, deposit-not-yet-held, same-entity-lowers-cap.
- **Ignoring `partner_scope`** ⇒ counts internal moves.
- **Double-counting deposits** (offset outflow AND raise the cap).
- **Wrong floor / boundary** (`>=` vs `>`, round vs floor).
- **Partial write on violation** ⇒ fails "writes no lines".

> If any failure traces to a flaky test, missing dependency, or ambiguous spec, that
> is a task-setup defect — fix the task before submitting, do not record it as a model
> reasoning gap.

## Anti-Cheating Analysis

- **Hardcoded outputs:** tests assert observable behavior — a raised error class,
  persisted vs. absent `Line` rows, and recomputed `Money` balances (e.g.
  `change { wallet.balance }.by(Money.new(-60_00))`). There are no magic output
  strings to echo.
- **Overfitting to visible tests:** `pass_to_pass` carries 12 existing-repo
  regressions (transfer/account/balance_calculator/line specs) plus a within-cap
  happy-path invariant. An over-restrictive solution that rejects legitimate
  sub-cap withdrawals fails the invariant; a solution that breaks the ledger
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

- `instruction.md` is now final human-written spec — see `SPEC_CONTRACT.md` for source of truth.
- Calibration: after underspecifying (removed trajectory reconstruction hint and detail-mechanism hint), difficulty recovered: avocado 1/5, gpt 0/5 vs previous 5/5.

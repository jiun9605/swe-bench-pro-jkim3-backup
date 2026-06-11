# SPEC_CONTRACT — double_entry rolling 24h withdrawal limit

> **Purpose.** This file lists every name and semantic the graded tests depend
> on, so the human author can write `instruction.md` **by hand** without an LLM.
> It is NOT the task prompt. Do not paste this verbatim into `instruction.md`;
> use it as the source of truth for what a correct solution must satisfy, then
> write a succinct problem statement in your own words. (Per AAI policy no
> LLM-generated tokens may appear in `instruction.md`.)

## Feature, in one line
Add an optional **per-account rolling 24-hour DYNAMIC withdrawal limit** to
DoubleEntry: the cap is a configured ratio of the account's time-weighted average
balance over the trailing 24h, enforced inside the transfer lock so concurrent
transfers cannot race past it.

## Public surface the tests rely on

| Name | Kind | Semantic the tests assert |
|------|------|---------------------------|
| `DoubleEntry::WithdrawalLimitExceeded` | error class | Raised when a cross-entity transfer OUT of a limited account would push its trailing-24h outflow over the dynamic cap. (Reference solution subclasses `DoubleEntryError`; tests only assert the specific class is raised.) |
| `withdrawal_limit_ratio:` | account attribute | Accepted by `accounts.define(...)` / `Account.new`. A numeric ratio (e.g. `0.5`), or `nil`. `nil` (the default for every existing account) ⇒ unchanged behavior. |
| `Account#withdrawal_limit_ratio` | reader | Returns the configured ratio (or `nil`). Must also be reachable from an `Account::Instance` (i.e. delegated), because `Transfer#process` works with account instances. |

The attribute is wired in via the existing attributes-hash flow: `Account::Set#define`
already forwards its hash to `Account.new`, so no change is needed there — only
`Account.new` must read the new key and expose it (instance included).

## Behavioral contract (what each test pins)

For a cross-entity withdrawal out of a limited account:
`reject iff (gross cross-entity outflow in window) + amount > cap`, where
`cap = (ratio × time_weighted_avg_balance_over_window).floor`. "Entity" =
`scope_identity`; a line is cross-entity iff its `partner_scope` differs from the
account's own scope.

1. **Dynamic cap = ratio × time-weighted average balance.** The cap is the
   configured ratio times the account's balance **averaged by the time each
   balance level was held** over `(now − 24h) .. now`, floored to whole cents.
   This is NOT `ratio × current_balance` and NOT `ratio × mean(per-line
   balances)` — it is the time integral of the balance trajectory divided by the
   window length. The trajectory is reconstructed from the balance carried into
   the window plus each in-window line's stored running balance.
2. **Cross-entity outflow consumes the cap, net of reversals.** Consumption is
   the sum of cross-entity **debits** (withdrawals to a different scope) in the
   window, **minus any reversal of those withdrawals**, floored at zero. A
   *reversal* is a cross-entity **credit** that shares its `detail` record with a
   cross-entity debit (the refund of a specific withdrawal); it gives back the
   allowance that withdrawal consumed (full or partial by amount). An **ordinary
   deposit** (a cross-entity credit with **no** matching `detail`) is **not** a
   reversal: it does not give back allowance and raises capacity only through the
   average-balance term, so it is never double-counted. Over-refunding (reversal >
   its withdrawal) does not create negative consumption — the net is floored at
   zero.
3. **Cross-entity only.** Same-entity moves (same scope) never consume the cap,
   and a same-entity transfer is not checked at all. But a same-entity move DOES
   change the account's real balance, so it affects the average-balance term (and
   thus the cap).
4. **Trailing 24h window / time-weighting.** A balance held only part of the
   window contributes proportionally; a deposit not yet held for any time adds ~0
   to the average (so it grants ~0 capacity immediately); an account with no
   balance history has a zero cap (all verified with Timecop).
5. **Inclusive boundary.** A withdrawal whose amount exactly equals the remaining
   allowance is allowed; one cent more is rejected.
6. **Atomic / consistent under lock.** The windowed read happens **inside the
   `Locking.lock_accounts` block in `Transfer#process`, before any line is
   written**, and both the outflow and the average are computed from lines that
   exist BEFORE this transfer (no circularity). On violation, raise and write
   **no lines** — balances unchanged.
7. **Per-entity.** The limit is per account **identifier + scope**. One entity's
   limit does not affect another entity's same-named account.
8. **Currency.** All `Money` math stays in the account's currency.
9. **Unlimited accounts unaffected.** Accounts with `withdrawal_limit_ratio`
   unset (`nil`) behave exactly as before — no new error path, no regressions.

> Three columns of `Line` carry the difficulty: `partner_scope` (to separate
> cross-entity from internal flow), the per-line `balance` (to reconstruct the
> balance trajectory for the time-weighted average), and `detail_type`/`detail_id`
> (to match a reversal credit to the withdrawal it refunds). A solution that sums
> `Line.debits` without `partner_scope`, that uses current/mean balance instead of
> the time-weighted integral, that ignores reversals, or that treats every
> cross-entity credit (not just detail-matched reversals) as giving back
> allowance, fails the corresponding examples.

## Files the reference solution touches (for your awareness — do NOT name these in the prompt)
- `lib/double_entry/errors.rb` — the new error class.
- `lib/double_entry/account.rb` — read + expose `withdrawal_limit_ratio`.
- `lib/double_entry/transfer.rb` — the windowed check + time-weighted average inside the lock.

The prompt should describe the **behavior**, not the file/method names — a
developer with knowledge of this codebase can locate the lock path and the
account-attributes flow themselves. Stating the error class name and the
configuration key name is fine (tests depend on them); naming private methods or
the exact diff is over-specification.

## Test harness facts (already built — for reference only)
- Tests: `spec/double_entry/withdrawal_limit_spec.rb` (new, 14 examples) +
  `:wallet` (limited), `:external` (counterparty), `:vault` (same-entity)
  accounts / 4 transfer routes added to `spec/support/accounts.rb`, delivered via
  `test_patch`. `:external` is driven at a *different* scope than `:wallet` so
  wallet→external is cross-entity; wallet↔vault is same-entity.
- DB: SQLite only (`DB=sqlite`), gemfile `Gemfile.rails-8.0.x`.
- `fail_to_pass` (13): over-cap (+no lines), time-weighted cap (vs current
  balance), cap grows with hold time, cumulative outflow, same-entity-withdrawal
  (no consume), same-entity-move-lowers-cap (time-weighted balance), zero-cap with
  no history, deposit-not-yet-held grants ~0, per-entity, reversal gives back
  allowance, ordinary-deposit does NOT give back allowance, partial reversal,
  over-reversal floors net consumption at zero.
- `pass_to_pass` (13): the below-limit happy path (guards against an
  over-restrictive solution) + 12 existing-repo regressions across
  transfer/account/balance_calculator/line specs.
- Verified: 69/69 on the 5 selected spec files with the reference solution
  (3 random seeds + a 2s-delay determinism run); base (no solution) = 13 fail /
  1 pass on the new spec.

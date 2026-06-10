# SPEC_CONTRACT — double_entry rolling 24h withdrawal limit

> **Purpose.** This file lists every name and semantic the graded tests depend
> on, so the human author can write `instruction.md` **by hand** without an LLM.
> It is NOT the task prompt. Do not paste this verbatim into `instruction.md`;
> use it as the source of truth for what a correct solution must satisfy, then
> write a succinct problem statement in your own words. (Per AAI policy no
> LLM-generated tokens may appear in `instruction.md`.)

## Feature, in one line
Add an optional **per-account rolling 24-hour withdrawal limit** to DoubleEntry,
enforced inside the transfer lock so concurrent transfers cannot race past it.

## Public surface the tests rely on

| Name | Kind | Semantic the tests assert |
|------|------|---------------------------|
| `DoubleEntry::WithdrawalLimitExceeded` | error class | Raised when a transfer OUT of a limited account would push its trailing-24h outflow over the limit. (Reference solution subclasses `DoubleEntryError`; tests only assert the specific class is raised.) |
| `daily_withdrawal_limit:` | account attribute | Accepted by `accounts.define(...)` / `Account.new`. A `Money` value in the account's currency, or `nil`. `nil` (the default for every existing account) ⇒ unchanged behavior. |
| `Account#daily_withdrawal_limit` | reader | Returns the configured limit (or `nil`). Must also be reachable from an `Account::Instance` (i.e. delegated), because `Transfer#process` works with account instances. |

The attribute is wired in via the existing attributes-hash flow: `Account::Set#define`
already forwards its hash to `Account.new`, so no change is needed there — only
`Account.new` must read the new key and expose it (instance included).

## Behavioral contract (what each test pins)

The cap is on the account's **net cross-entity outflow** over a trailing 24h
window. "Entity" = `scope_identity`. A line is cross-entity iff its
`partner_scope` differs from the account's own scope.

1. **Cross-entity only.** Only flows whose partner is in a *different* scope
   count. Transfers between two accounts of the same entity (same scope) are
   internal — they neither consume the limit nor, when the current transfer is
   itself same-entity, trigger the check at all.
2. **Net of deposits.** Within the window, cross-entity deposits offset
   cross-entity withdrawals one-for-one. Net withdrawn = (cross-entity outflow −
   cross-entity inflow) over the window.
3. **No floor (banking).** If cross-entity inflow exceeds outflow, net withdrawn
   is negative, so an entity that has paid in more than it has taken out may
   withdraw that surplus *on top of* the limit (deposit 1000 ⇒ may withdraw
   1000 + limit). Net is **not** clamped at zero.
4. **Trailing 24h window.** Only lines with `created_at` in `(now − 24h) .. now`
   count; older lines (including offsetting deposits) drop out, which can shrink
   a previously-available allowance (verified with Timecop).
5. **Inclusive boundary.** A transfer whose amount exactly equals the remaining
   allowance is allowed; one cent more is rejected.
6. **Atomic / consistent under lock.** The windowed check happens **inside the
   `Locking.lock_accounts` block in `Transfer#process`, before any line is
   written.** On violation, raise and write **no lines** — balances unchanged.
7. **Per-entity.** The limit is per account **identifier + scope**. One entity's
   limit does not affect another entity's same-named account.
8. **Currency.** All `Money` math stays in the account's currency.
9. **Unlimited accounts unaffected.** Accounts with `daily_withdrawal_limit`
   unset (`nil`) behave exactly as before — no new error path, no regressions.

> The cross-entity test hinges on the `partner_scope` column of `Line`
> (persisted, indexed). A solution that sums `Line.debits` without filtering by
> `partner_scope`, or that ignores credits, fails the same-entity and
> deposit-offset examples.

## Files the reference solution touches (for your awareness — do NOT name these in the prompt)
- `lib/double_entry/errors.rb` — the new error class.
- `lib/double_entry/account.rb` — read + expose `daily_withdrawal_limit`.
- `lib/double_entry/transfer.rb` — the windowed check inside the lock.

The prompt should describe the **behavior**, not the file/method names — a
developer with knowledge of this codebase can locate the lock path and the
account-attributes flow themselves. Stating the error class name and the
configuration key name is fine (tests depend on them); naming private methods or
the exact diff is over-specification.

## Test harness facts (already built — for reference only)
- Tests: `spec/double_entry/withdrawal_limit_spec.rb` (new, 10 examples) +
  `:wallet` (limited), `:external` (counterparty), `:vault` (same-entity)
  accounts / 4 transfer routes added to `spec/support/accounts.rb`, delivered via
  `test_patch`. `:external` is driven at a *different* scope than `:wallet` so
  wallet→external is cross-entity; wallet↔vault is same-entity.
- DB: SQLite only (`DB=sqlite`), gemfile `Gemfile.rails-8.0.x`.
- `fail_to_pass` (9): single-over-limit (+no lines), cumulative, window-expiry,
  inclusive-boundary (+1¢), deposit-offset (banking), same-entity-withdrawal
  (no consume), same-entity-deposit (no replenish), offsetting-deposit-ages-out,
  per-entity.
- `pass_to_pass` (13): the below-limit happy path (guards against an
  over-restrictive solution) + 12 existing-repo regressions across
  transfer/account/balance_calculator/line specs.
- Verified: 65/65 on the 5 selected spec files with the reference solution
  (3 random seeds); base (no solution) = 9 fail / 1 pass on the new spec.

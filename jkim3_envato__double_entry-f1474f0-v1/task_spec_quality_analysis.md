# Task Spec Quality Analysis — double_entry rolling 24h net withdrawal limit

## Verification (Docker, ruby:3.3-slim, DB=sqlite, Gemfile.rails-8.0.x)

| State | Result |
|-------|--------|
| Base commit `f1474f0`, no solution | 13 pass / 9 fail_to_pass missing → **FAILED** (expected) |
| Base + `solution/solve.sh` | 22/22 required pass, 65 total → **PASSED** |

FAIL_TO_PASS (9) and PASS_TO_PASS (13) both behave as declared.

## Missing Information

| # | Description | Inferable from Codebase? | Explanation |
|---|-------------|--------------------------|-------------|
| 1 | Error class `DoubleEntry::WithdrawalLimitExceeded` (exact name) | No — but **given in spec** | Tests assert this exact class. Not derivable from the repo; spec correctly states it. Tests don't check message or superclass, so the message wording is free. |
| 2 | Config attribute name `daily_withdrawal_limit` on `accounts.define` | No — but **given in spec** | A brand-new account attribute; cannot be inferred. Spec correctly names it. |
| 3 | "Entity = shared scope"; cross-entity = partner in a different scope | Yes | `Line` persists `scope` and `partner_scope` (migration template + `Line#partner_account=`); `Account::Instance#scope_identity` defines identity. A dev can find that cross-entity filtering keys off `partner_scope`. Spec describes the concept ("share a scope") without naming columns — good. |
| 4 | Net-of-deposits offset, one-for-one, **no floor** (surplus withdrawable on top of limit) | No — but **given in spec** | A design decision, not derivable from code. Required to pass deposit-offset test. Spec states it. |
| 5 | Inclusive boundary (amount == remaining allowance is allowed) | No — but **given in spec** | Off-by-one design choice; tests pin it; spec states it. |
| 6 | Atomic rejection — no lines written / balances unchanged | Partly | Spec states the observable ("persist nothing"). The lock path (`Locking.lock_accounts` in `Transfer#process`) is discoverable; no concurrency test exists, so only the persist-nothing observable matters. |
| 7 | Trailing-24h window; offsetting deposits age out | No — but **given in spec** | "rolling 24-hour" + "trailing 24 hours" stated; tests use Timecop with a 24h+60s margin so the exact inclusive/exclusive edge is untested. |
| 8 | Per-(identifier+scope) independence across entities | Yes | Falls out naturally from querying lines by `account` + `scope`; not separately needed in spec. |

**Conclusion:** Every item the tests depend on that is *not* inferable (1, 2, 4, 5, 7) is already stated in `instruction.md`. Every item that *is* inferable (3, 8, and the lock path in 6) is correctly left for the developer to discover. Nothing required is missing; nothing privileged (file names, method names, column names, the query shape) is disclosed.

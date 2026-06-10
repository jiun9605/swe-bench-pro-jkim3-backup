Add an optional per-account rolling 24-hour withdrawal limit.

Each account may be configured with a `daily_withdrawal_limit`: the maximum total
amount that may leave the account within any trailing 24-hour window. The window
is measured backwards from the moment of a transfer — it covers outflows in
`(now - 24h) .. now`. Outflows older than 24 hours no longer count toward the
limit.

Rules:
- Only money leaving the account (transfers OUT) counts toward the limit.
  Deposits into the account are never counted.
- A transfer is rejected if it would push the account's trailing-24h outflow
  above the limit. A transfer whose amount exactly equals the remaining
  allowance is allowed; one unit more is rejected (reject iff
  `outflow_so_far + amount > limit`).
- The limit is per account instance — that is, per account identifier + scope.
  A limit on one account does not affect another account with the same name in a
  different scope.
- An account with no `daily_withdrawal_limit` configured (the default) behaves
  exactly as before, with no limit enforced.

On rejection, raise `DoubleEntry::WithdrawalLimitExceeded` and persist nothing:
no lines are written and balances are left unchanged.

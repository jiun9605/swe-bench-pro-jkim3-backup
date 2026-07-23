Add a rolling 24h per-account dynamic withdrawal limit to DoubleEntry.

Accounts can set withdrawal_limit_ratio (e.g. 0.5). nil = unlimited, behaves as today.

We check cross-entity withdrawals only — money leaving to a different entity. Same scope = same entity, so same-scope is internal. Internal never checked, never consumes, but it still changes real balance.

Cap is dynamic: ratio * time-weighted average balance over trailing 24h, floored to cents. Time-weighted, not current balance.

A withdrawal can be reversed/refunded — reversal gives back the allowance it consumed. Partial reversal gives back partially, over-refunding doesn't create extra allowance. Ordinary deposit isn't a reversal, only affects cap through average.

Reject if (net cross-entity outflow in trailing 24h, floored at 0, net of reversals) + current amount > cap. Landing exactly on remaining is allowed. Ordinary deposit doesn't offset outflow.

On reject raise DoubleEntry::WithdrawalLimitExceeded, write no lines — balances unchanged.

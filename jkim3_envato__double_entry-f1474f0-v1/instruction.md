Add an optional per-account rolling 24-hour dynamic withdrawal limit to DoubleEntry.

An account can be configured with a withdrawal_limit_ratio (a number such as 0.5); when unset (the default, nil), the account is unlimited and behaves exactly as today.

The limit applies to cross-entity withdrawals — money leaving the account to a different entity, where two accounts belong to the same entity when they share a scope. A transfer between two accounts of the same entity is internal: it is never checked against the limit and never consumes it.

For a cross-entity withdrawal, the cap is dynamic: withdrawal_limit_ratio times the account's time-weighted average balance over the trailing 24 hours, floored to whole cents. Time-weighted means each balance level is weighted by how long it was held during the window (the balance carried into the window, then each change held until the next), not the current balance and not the simple average of past balances.

A cross-entity withdrawal must be rejected if the account's gross cross-entity outflow over the trailing 24 hours, plus the current transfer, would exceed that cap. A withdrawal landing exactly on the remaining allowance is allowed. Deposits do not directly offset outflow — they affect the limit only by raising the average balance.

On rejection, raise DoubleEntry::WithdrawalLimitExceeded and persist nothing — no lines written, balances unchanged.

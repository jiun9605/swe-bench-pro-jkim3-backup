Add an optional per-account rolling 24-hour net withdrawal limit to DoubleEntry.

An account can be configured with a daily_withdrawal_limit (a Money value in the account's currency); when unset (the default, nil), the account is unlimited and behaves exactly as today.

The limit caps net cross-entity outflow over the trailing 24 hours. Two accounts belong to the same entity when they share a scope. Money moving between two accounts of the same entity is an internal move: it never counts toward the limit, and a transfer that is itself internal is never blocked by it. Only money crossing to a different entity counts, and within the window cross-entity deposits offset cross-entity withdrawals one-for-one. There is no floor — an entity that has received more from other entities than it has sent may withdraw that surplus on top of the limit.

A cross-entity transfer out of a limited account must be rejected if it would push the account's net cross-entity outflow over the trailing 24 hours above the limit. A transfer landing exactly on the remaining allowance is allowed.

On rejection, raise DoubleEntry::WithdrawalLimitExceeded and persist nothing — no lines written, balances unchanged.

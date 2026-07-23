Create per-account 24-hour rolling based dynamic withdrawal limit to this repo Double Entry.

We can set withdrawal_limit_ratio (a number such as 0.3). When this is not set (the default, nil), the account is unlimited and behaves exactly as today.

For cross-entity withdrawals where the transfer is between two accounts that belongs to the same etnity, it is considered "internal" transfer and is not checked against the limit.

For a cross-entity withdrawal, the cap is dynamic: withdrawal_limit_ratio times the account's time-weighted average balance over the trailing 24 hours, floored to whole cents. Time-weighted means each balance level is weighted by how long it was held during the window (the balance carried into the window, then each change held until the next), not the current balance and not the simple average of past balances.

A cross-entity withdrawal can later be reversed/refunded: a transfer back to a given account that references the same detail as the original withdrawal undoes that withdrawal's consumption of the limit (a partial refund gives back proportionally; refunding more than was withdrawn never creates extra allowance). An ordinary deposit that doesn't reference a prior withdrawal is not a reversal and only affects the limit through the balance it adds.

We reject the cross-entity withdrawl once the limit is exceeded for the given account's transfer - net of any reversals (above), floored at zero — plus the current transfer, would exceed that cap. A withdrawal landing exactly on the remaining allowance is allowed. An ordinary deposit (one that is not a reversal) does not offset outflow; it affects the limit only by raising the average balance.

Once the transfer is rejected, we raise DoubleEntry::WithdrawalLimitExceeded. Upon raise, we leave no trace — no lines written, balances unchanged.

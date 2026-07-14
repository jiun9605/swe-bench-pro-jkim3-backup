---
name: fedwire-amount-scaling
description: Amount field parsing, formatting, validation, and scaling rules for FedWire fixed-width 12-digit amount representation in moov-io/wire
when-to-use: Use when working with Amount struct, amount parsing from FedWire wire format, amount String formatting, amount validation rules, maximum amount enforcement, or fixed-width numeric field handling in payment messages.
skill_type: domain_knowledge
---

# FedWire Amount Handling

FedWire amount fields represent monetary values in fixed-width numeric format without decimal separators, requiring careful parsing and formatting to preserve precision and prevent overflow.

## Core Concepts

Amount tag {2000} carries 12 numeric digits representing dollars and cents with implied decimal point two positions from right. Maximum value is $9,999,999,999.99 represented as string "999999999999". Minimum is zero represented as "000000000000" but zero amount has special handling depending on BFC and TypeSubType — some message types prohibit zero amount.

No negative amounts permitted in FedWire Funds Service; negative is represented via separate debit/credit posting direction not via sign in amount field. Amount must be numeric characters 0-9 only, no commas, no decimal point, no sign, left padded with zeros to exactly 12 characters in wire format.

In Go struct representation, Amount struct holds Amount string field with json tag, plus tag private string for wire tag identifier. Parse method extracts 12 characters after tag, validates numeric via regex or custom numeric check, stores as string preserving leading zeros for roundtrip fidelity.

## Repository Conventions in moov-io/wire

- Amount struct defined in amount.go with Parse, String, Validate, Format methods following standard tag struct pattern used across codebase.
- Validate checks length 12, numeric-only via IsNumeric helper from converters, and value range via big integer comparison against max.
- String method returns fixed-width 12 character string via numericStringField helper padding left with zeros.
- Format method accepts FormatOptions for variable length fields false by default matching FedWire fixed-width spec; variable length true used only in specific JSON or debug contexts.
- Test helpers mockAmount() defined in amount_test.go returns valid Amount with value "1000" meaning $10.00.
- Amount field in FEDWireMessage is mandatory across all BFCs via mandatoryFields() check in fedWireMessage.go verify path.

## Design Patterns

Fixed-width numeric parsing pattern: extract substring at fixed offset, trim spaces then validate length, check IsNumeric, convert to big.Int for range comparison to avoid int64 overflow on 12 digits (though 12 digits fits in int64, codebase uses string preservation for roundtrip).

Error construction uses fieldError("Amount", ErrValidLength) or ErrNonNumeric or ErrAmount for out of range. Follow existing error sentinel usage rather than creating new error types.

When extending amount handling for new feature, preserve string-based internal representation to maintain leading zero roundtrip fidelity required by FedWire spec and existing tests expecting exact string output from String() method.

## Failure Modes

- Using strconv.Atoi or ParseInt without handling leading zeros loses roundtrip fidelity; String() output will not match input exactly causing writer_test failures.
- Forgetting left pad to 12 characters in String() causes fixed-width violation and downstream parse failures in receiving systems.
- Allowing negative sign or decimal point in Validate passes unit tests that only check happy path but fails FedWire spec compliance and causes interop issues.
- Maximum amount boundary off-by-one: 12 nines is max inclusive, 10 billion (1000000000000) is out of range and must error.

## Testing Strategy

Table-driven tests covering valid amount at boundaries 0, 1, max-1, max, invalid length 11 and 13, non-numeric characters, negative sign, decimal point, empty string. Existing amount_test.go provides pattern with TestAmountString, TestAmountValid, TestAmountInvalid etc. Use mockAmount helper as baseline then mutate Amount field to trigger specific error case.

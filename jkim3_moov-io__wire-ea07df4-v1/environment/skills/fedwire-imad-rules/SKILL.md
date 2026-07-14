---
name: fedwire-imad-rules
description: Input and Output Message Accountability Data parsing, validation, and generation patterns for FedWire IMAD and OMAD fields in moov-io/wire
when-to-use: Use when working with IMAD OMAD fields, accountability data parsing, date validation, sequence number handling, input or output message tracking, or accountability data generation in FedWire implementations.
skill_type: domain_knowledge
---

# FedWire IMAD OMAD Rules

FedWire accountability data provides unique identifiers for tracking messages through Federal Reserve systems. IMAD identifies input messages from sending institution perspective; OMAD identifies output messages from Federal Reserve perspective.

## Core Concepts

IMAD format in tag {1520} is 26 characters structured as YYYYMMDD date 8 digits, source routing number 9 digits, filler 1 character typically blank, sequence number 8 digits left padded with zeros. OMAD format in tag {1400} follows similar pattern with output date, destination routing, and sequence.

Date portion must represent valid calendar date in Gregorian calendar, not in future relative to processing date, typically within FedWire operating window. February 29 valid only on leap years. Zero date or all-nines date are invalid sentinel values that must be rejected.

Routing number portion must be 9 numeric digits. While FedWire does not require routing number checksum validation at message format level in this library, numeric-only constraint applies.

Sequence number must be numeric, non-zero padded to 8 digits, range 00000001 to 99999999 inclusive. All-zero sequence indicates missing accountability data and must error.

## Repository Conventions in moov-io/wire

- InputMessageAccountabilityData struct defined in inputMessageAccountabilityData.go with fields InputCycleDate string, InputSource string, InputSequenceNumber string, plus tag string private.
- Parse method expects fixed 26 character input after 6-character tag, extracts substrings at fixed offsets, trims spaces.
- Validate method currently checks length and alphanumeric constraints but does not enforce semantic date validity or future date prohibition in base version — extension point for stricter validation tasks.
- OMAD struct in outputMessageAccountabilityData.go follows parallel pattern with OutputCycleDate, OutputDestination, OutputSequenceNumber.
- Error construction uses fieldError with ErrValidLength, ErrNonNumeric, or custom error sentinels defined in errors.go.
- Test helpers mockInputMessageAccountabilityData() defined in inputMessageAccountabilityData_test.go returns valid fixture with date 20200102 source 121042882 sequence 000001.

## Design Patterns

Strict date validation pattern in Go uses time.Parse with layout "20060102" then checks parsed time not after time.Now, not before reasonable epoch like 1970, and reformat matches input to catch invalid dates like February 30 that Parse normalizes.

Sequence validation converts string to integer via strconv.Atoi after trimming leading zeros, checks >0 and <=99999999, then reformats with leading zeros to ensure canonical form.

When extending Validate method, preserve existing length and alphanumeric checks first for backward compatibility, add semantic checks after structural checks to provide clear error precedence.

## Failure Modes

- time.Parse normalizes invalid dates silently unless output formatted back to input string is compared for equality — February 30 becomes March 2 without error unless checked.
- Future date check using time.Now introduces non-determinism in tests unless test uses fixed past date fixture or mocks time source via build tag; prefer validating date <= today at runtime but use fixed past dates in tests to avoid flakiness.
- Leading zeros stripped by Atoi must be restored for error messages to show original input format expected by FedWire spec.
- OMAD and IMAD share similar structure but different tag numbers and field names; ensure changes apply to correct struct or both if task scope requires symmetry.

## Testing Strategy

Table-driven tests covering valid IMAD, invalid date format non-numeric, invalid calendar date February 30, future date, zero sequence, sequence too long, routing non-numeric, empty input. Existing tests in inputMessageAccountabilityData_test.go provide pattern for mock fixture and error assertion via require.EqualError with fieldError expected string.

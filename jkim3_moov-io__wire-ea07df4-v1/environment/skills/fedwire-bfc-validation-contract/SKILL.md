---
name: fedwire-bfc-validation-contract
description: Business Function Code validation patterns for FedWire messages including mandatory tag enforcement, prohibited tag enforcement, and TypeSubType whitelisting in moov-io/wire
when-to-use: Use when implementing FedWire message validation logic in moov-io/wire, especially for Business Function Code handling, BFC-specific tag rules, TypeSubType whitelist associations, FEDWireMessage validation dispatch, or extending validators in fedWireMessage.go.
skill_type: domain_knowledge
---

# FedWire BFC Validation Contract

FedWire Funds Service messages use a Business Function Code to denote message purpose. Understanding the contract between BFC and allowed tag sets is essential for correct validation in moov-io/wire.

## Core Concepts

A FEDWireMessage aggregates approximately 40 optional tag structs, each representing a FedWire tag like {1500} SenderSupplied, {1510} TypeSubType, {2000} Amount, {3600} BusinessFunctionCode, {9000} ServiceMessage. Validation must enforce business rules beyond generic field format checks.

Business Function Code values are three-letter codes defined as constants:
- BTR Bank Transfer, CKS Check Same Day Settlement, CTP Customer Transfer Plus, CTR Customer Transfer, DEP Deposit to Sender's Account, DRB Bank Drawdown Request, DRC Customer Corporate Drawdown Request, DRW Drawdown Response, FFR Fed Funds Returned, FFS Fed Funds Sold, SVC Service Message

Each BFC represents a distinct business scenario with its own allowed tag sets defined in FedWire operating circulars and Format Reference Guide section 15. TypeSubType combinations are further restricted per BFC via whitelists. For example, SVC (Service Message) uses tag {9000} ServiceMessage which carries free-text service information across twelve optional lines LineOne through LineTwelve, with LineOne being the primary required line per its own field inclusion rule. BTR (Bank Transfer) and CTR (Customer Transfer) have different allowed tag sets that do not include ServiceMessage in their valid combinations per the format guide.

A FEDWireMessage includes many optional tags; common mandatory tags are enforced for all messages regardless of BFC, while additional BFC-specific rules (mandatory presence, prohibited absence, TypeSubType whitelist) apply after dispatch in BFC-specific validators.

ServiceMessage struct validation in serviceMessage.go checks LineOne presence and alphanumeric/length constraints, and file inclusion helpers in other tags often use strings package for content checks.

## Repository Conventions in moov-io/wire

- `FEDWireMessage` struct defined in fedWireMessage.go holds pointer fields for each tag with json omitempty tags.
- `File.Validate()` calls `fwm.verify()` which performs common mandatory field checks then switches on `BusinessFunctionCode.BusinessFunctionCode` string value to dispatch to BFC-specific validator.
- BFC-specific validators follow naming pattern `validateBankTransfer`, `validateCustomerTransfer`, `validateCustomerTransferPlus`, `validateServiceMessage`, etc., located in fedWireMessage.go.
- TypeSubType whitelists defined in associatedTypeSubTypes.go as variables like `svcTypeSubTypes`, `btrTypeSubTypes`, `ctrTypeSubTypes`, each an `associatedTypeSubTypes` slice with a `Contains` method checking concatenated TypeCode+SubTypeCode.
- Field error construction uses helper `fieldError(fieldName string, err error, ...value)` returning formatted error. Existing error sentinels from errors.go such as `ErrFieldRequired`, `ErrInvalidProperty`, `ErrTransactionTypeCode` are reused.
- Each tag struct (e.g., ServiceMessage in serviceMessage.go, Amount, Beneficiary) has its own `Validate()` method for format and alphanumeric checks, called from common mandatory checks or from reader parsing path.
- Mock helpers for tests are defined in `*_test.go` files in same package.

## Design Patterns

Common mandatory tags (1500 SenderSupplied, 1510 TypeSubType, 1520 IMAD, 2000 Amount, 3100 SenderDI, 3400 ReceiverDI, 3600 BusinessFunctionCode first element) are checked in `mandatoryFields()` regardless of BFC, each via dedicated `validateX()` that checks nil then delegates to tag's `Validate()`.

BFC-specific validators live in fedWireMessage.go and follow the pattern `validate< BFCName >` (e.g., `validateBankTransfer`, `validateCustomerTransfer`, `validateCustomerTransferPlus`, `validateServiceMessage`). They are dispatched from `validateBusinessFunctionCode()` switch on `BusinessFunctionCode.BusinessFunctionCode`.

BFC-specific validators typically handle:
- TypeSubType whitelist validation via `associatedTypeSubTypes.Contains(TypeCode+SubTypeCode)` returning `NewErrBusinessFunctionCodeProperty` on mismatch. Whitelists are defined in associatedTypeSubTypes.go (`btrTypeSubTypes`, `ctrTypeSubTypes`, `svcTypeSubTypes`, etc.).
- Prohibited tag absence via helper `checkProhibited< BFC >Tags` returning `fieldError` with `ErrInvalidProperty`
- Optional mandatory tag presence for some BFCs via `checkMandatory< BFC >Tags` helper. Examples: CTP, DRW, DRB, DRC validators implement mandatory checks for their respective business flows. The helper naming and error construction pattern follows existing validators; reuse `fieldError` with `ErrFieldRequired` for missing required tags.

General ordering within a BFC validator follows neighboring implementations: TypeSubType whitelist is checked first, then BFC-specific mandatory presence (if any), then prohibited tags. This ordering ensures that fundamental type errors are reported before business-rule violations.

Dispatch path is `File.Validate()` -> `fwm.verify()` (common mandatory) -> `validateBusinessFunctionCode()` -> BFC-specific validator. Tests should exercise the full dispatch via `NewFile()` + `AddFEDWireMessage()` + `file.Validate()` rather than calling BFC helpers directly.

## Failure Modes

- Missing common mandatory fields (SenderSupplied, TypeSubType, IMAD, Amount, SenderDI, ReceiverDI, BFC) causes `ErrFieldRequired`.
- Invalid TypeSubType for given BFC (e.g., using "00" BasicFundsTransfer where BFC only allows "01" RequestReversal) returns business function code property error.
- Prohibited tags present for BFC (e.g., LocalInstrument present where BFC prohibits it) returns `ErrInvalidProperty`.
- Nil pointer dereference when accessing optional tag fields without nil guard before Validate or field access.
- Incorrect whitelist variable used (e.g., checking `btrTypeSubTypes` for SVC message) leads to valid TypeSubTypes being rejected or invalid accepted.
- Test that only exercises direct helper `checkProhibitedX` instead of full `File.Validate()` path misses dispatch wiring issues.

## Testing Strategy

Define test functions in package wire using mock helpers like `mockSenderSupplied()`, `mockTypeSubType()`, `mockBusinessFunctionCode()` to construct minimal valid FEDWireMessage, then modify specific fields to trigger error conditions. Use `NewFile()` then `file.AddFEDWireMessage(fwm)` then `file.Validate()` to trigger full validation chain including BFC dispatch via `validateBusinessFunctionCode()`.

TypeSubType whitelists per BFC are defined in associatedTypeSubTypes.go (e.g., `btrTypeSubTypes`, `ctrTypeSubTypes`, `svcTypeSubTypes`). Each whitelist has a `Contains` method. Valid combinations differ per BFC, so cover both valid and invalid paths for the BFC under test. For prohibited/mandatory coverage, use `go test -run` for targeted execution and full suite for regression.

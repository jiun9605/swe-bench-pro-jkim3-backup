---
name: fedwire-bfc-validation-contract
description: Business Function Code validation patterns for FedWire messages including mandatory tag enforcement, prohibited tag enforcement, and TypeSubType whitelisting in moov-io/wire
when-to-use: Use when implementing FedWire message validation logic in moov-io/wire, especially for Business Function Code handling, tag mandatory or prohibited rules, TypeSubType whitelists, ServiceMessage handling, SVC business function code, ServiceMessage tag, validateServiceMessage, checkMandatory, checkProhibited, ServiceMessage mandatory, SVC BFC, BusinessFunctionCode validation, or extending BFC-specific validators in fedWireMessage.go.
skill_type: domain_knowledge
---

# FedWire BFC Validation Contract

FedWire Funds Service messages use a Business Function Code to denote message purpose, and each BFC imposes distinct mandatory and prohibited tag sets. In moov-io/wire, validation is centralized but dispatched per BFC, requiring consistent patterns across validators.

## Core Concepts

A FEDWireMessage aggregates approximately 40 optional tag structs, each representing a FedWire tag like {1500} SenderSupplied, {1510} TypeSubType, {2000} Amount, {3600} BusinessFunctionCode, {9000} ServiceMessage. Validation must enforce BFC-specific business rules beyond generic field format checks.

Business Function Code values are three-letter codes defined as constants:
- BTR Bank Transfer, CKS Check Same Day Settlement, CTP Customer Transfer Plus, CTR Customer Transfer, DEP Deposit to Sender's Account, DRB Bank Drawdown Request, DRC Customer Corporate Drawdown Request, DRW Drawdown Response, FFR Fed Funds Returned, FFS Fed Funds Sold, SVC Service Message

Each BFC maps to a specific business scenario with defined mandatory tags that must be present and prohibited tags that must be absent for the message to be considered valid under FedWire operating circulars.

## Repository Conventions in moov-io/wire

- `FEDWireMessage` struct defined in fedWireMessage.go holds pointer fields for each tag, json omitempty tags for API serialization.
- `File.Validate()` calls `fwm.verify()` which performs mandatory field checks common to all messages then switches on `BusinessFunctionCode.BusinessFunctionCode` string value to dispatch to BFC-specific validator.
- BFC-specific validators follow naming pattern `validateBankTransfer`, `validateCustomerTransfer`, `validateCustomerTransferPlus`, `validateServiceMessage`, etc., located in fedWireMessage.go.
- Each validator typically enforces BFC-specific business rules: mandatory tag presence, prohibited tag absence, and TypeSubType whitelist validation via associatedTypeSubTypes map containment check. The exact ordering varies by validator; follow neighboring BFC implementations for consistency.
- TypeSubType whitelists defined in associatedTypeSubTypes.go as variables like `svcTypeSubTypes`, `btrTypeSubTypes`, `ctrTypeSubTypes`. Each is an associatedTypeSubTypes map from TypeCode+SubTypeCode concatenated string to boolean.
- Field error construction uses helper `fieldError(fieldName string, err error, ...value)` returning formatted error. Reuse existing error sentinels from errors.go rather than creating new types unless absolutely necessary.
- ServiceMessage struct defined in serviceMessage.go with tag {9000}, twelve optional string fields LineOne through LineTwelve. Its Validate method enforces content rules; BFC-level validation typically checks structural presence.
- Mock helpers for tests are defined in *_test.go files in same package and accessible from new test files. Use `NewFile()` then `file.AddFEDWireMessage(fwm)` then `file.Validate()` pattern seen in fedWiremessage_test.go to trigger full validation chain including BFC dispatch.

## Design Patterns

Mandatory tag enforcement across BFC validators typically extracts a helper that checks presence of required tag structs and returns an appropriate field error on absence. Prohibited tag enforcement uses either shared or bespoke helpers depending on BFC grouping. Validators compose these helpers along with TypeSubType whitelist checks; exact composition order follows neighboring BFC implementations for consistency.

When adding new mandatory logic, follow existing naming conventions in fedWireMessage.go, place helpers near related prohibited helpers for locality, and guard pointer dereferences to avoid panics during validation. Reuse existing error sentinels where possible.

## Failure Modes

- Nil pointer dereference when checking nested fields without nil guard on parent struct pointer.
- Adding mandatory check in generic verify() instead of BFC-specific validator causes false positives on other BFCs.
- Inconsistent ordering relative to prohibited checks or TypeSubType whitelist — follow neighboring BFC validators for consistency.
- Using wrong error sentinel for the condition type.
- Test only checking direct helper not full Validate path — full path via File.Validate ensures BFC dispatch wiring is correct.
- Incomplete test coverage leading to silent pass on base commit.

## Testing Strategy

Define table-driven or separate test functions in new test file under package wire, following existing naming patterns seen in fedWiremessage_test.go. Use mock helpers to construct minimal valid FEDWireMessage then modify specific fields to trigger error conditions.

For BFC validation changes, cover both positive and negative paths via file.Validate to ensure mandatory enforcement works and valid cases still pass, without regressing other BFC validators. Use `go test -run` for targeted execution and full suite for regression check.

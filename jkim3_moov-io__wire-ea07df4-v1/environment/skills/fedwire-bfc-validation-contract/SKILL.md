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
- BFC-specific validators follow naming pattern `validateBankTransfer`, `validateCustomerTransfer`, `validateCustomerTransferPlus`, `validateServiceMessage`, etc., located in fedWireMessage.go between lines 370 and 800 approximately.
- Each validator typically performs three steps in order: check mandatory tags via `checkMandatory...Tags()`, check prohibited tags via `checkProhibited...Tags()` or `checkSharedProhibitedTags()`, then validate TypeSubType against whitelist via associatedTypeSubTypes map containment check.
- TypeSubType whitelists defined in associatedTypeSubTypes.go as variables like `svcTypeSubTypes`, `btrTypeSubTypes`, `ctrTypeSubTypes`. Each is an associatedTypeSubTypes map from TypeCode+SubTypeCode concatenated string to boolean. Valid SVC combinations include FundsTransfer RequestReversal 1001, FundsTransfer RequestReversalPriorDay 1007, FundsTransfer RefusalRequestCredit 1032, FundsTransfer SSIServiceMessage 1090, and corresponding ForeignTransfer 20xx and SettlementTransfer 30xx variants.
- Field error construction uses helper `fieldError(fieldName string, err error, ...value)` returning formatted error. For missing required field use `fieldError("FieldName", ErrFieldRequired)`. For invalid property use `fieldError("FieldName", ErrInvalidProperty, value)`. Do not create new error sentinel types unless absolutely necessary; reuse existing ErrFieldRequired, ErrInvalidProperty, ErrBusinessFunctionCode, ErrTransactionTypeCode from errors.go.
- ServiceMessage struct defined in serviceMessage.go with tag {9000}, twelve optional string fields LineOne through LineTwelve each max 35 alphanumeric characters. Its Validate method requires LineOne non-empty and alphanumeric, tag must equal TagServiceMessage constant. BFC-level validation should check pointer non-nil presence; struct-level Validate handles content rules.
- Mock helpers for tests: `mockSenderSupplied()`, `mockTypeSubType()`, `mockInputMessageAccountabilityData()`, `mockAmount()`, `mockSenderDepositoryInstitution()`, `mockReceiverDepositoryInstitution()`, `mockBusinessFunctionCode()`, `createMockServiceMessageData()` defined in *_test.go files in same package and accessible from new test files. Use `NewFile()` then `file.AddFEDWireMessage(fwm)` then `file.Validate()` pattern seen in fedWiremessage_test.go to trigger full validation chain including BFC dispatch.

## Design Patterns

Mandatory tag enforcement pattern observed across codebase for BFCs other than SVC:

```go
func (fwm *FEDWireMessage) checkMandatoryXTags() error {
    if fwm.SomeTag == nil {
        return fieldError("SomeTag", ErrFieldRequired)
    }
    // additional field-level checks if needed beyond nil
    return nil
}
```

Then in validateX:
```go
if err := fwm.checkMandatoryXTags(); err != nil { return err }
if err := fym.checkProhibitedXTags(); err != nil { return err }
// TypeSubType whitelist check
```

Prohibited tag pattern uses checkSharedProhibitedTags for BFCs sharing same forbidden set (BTR, CKS, DEP, FFR, FFS, DRB, DRC, DRW share one set; CTR, CTP, SVC have bespoke prohibited functions). Shared function explicitly errors if ServiceMessage != nil, establishing symmetry expectation that ServiceMessage is prohibited everywhere except SVC where it should be mandatory.

When adding new mandatory check, follow existing naming, place helper near corresponding prohibited helper in fedWireMessage.go for locality, ensure nil pointer guard before accessing nested fields to avoid panic during validation.

## Failure Modes

- Nil pointer dereference when checking nested field without nil guard on parent struct pointer — always check `if fwm.ServiceMessage == nil` before accessing `fwm.ServiceMessage.LineOne`.
- Adding mandatory check in generic verify() instead of BFC-specific validator causes false positives on other BFCs that must prohibit the tag.
- Forgetting TypeSubType whitelist check order — whitelist should be checked after mandatory/prohibited or before depending on existing pattern in target validator; follow neighboring BFC validators for consistency.
- Using wrong error sentinel — ErrFieldRequired for missing mandatory tag, ErrInvalidProperty for present but forbidden tag, ErrBusinessFunctionCode for BFC mismatch, ErrTransactionTypeCode for invalid TransactionTypeCode value.
- Test only checking direct helper not full Validate path — full path via File.Validate ensures BFC dispatch wiring is correct and no regressions in other validators.
- Incomplete test coverage leading to silent pass on base commit — new tests must assert error on missing mandatory case, not just pass on valid case, to ensure fail_to_pass signal.

## Testing Strategy

Define table-driven or separate test functions in new test file under package wire, following existing naming like TestInvalid...For... and Test...Mandatory... patterns seen in fedWiremessage_test.go. Use mock helpers to construct minimal valid FEDWireMessage then modify specific field to trigger error condition.

For BFC mandatory enforcement, at minimum cover:
- BFC set to target value with mandatory tag omitted expecting error via file.Validate
- BFC set to target value with mandatory tag present but empty required subfield expecting error
- BFC set to target value with mandatory tag correctly populated expecting pass via file.Validate
- Existing pass_to_pass tests for same BFC with valid data continue passing to ensure no regression in prohibited tag checks or TypeSubType handling.

Use `go test -run TestName -v` pattern for targeted execution during development; full suite via `go test ./...` for regression check.

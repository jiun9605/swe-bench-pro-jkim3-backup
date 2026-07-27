---
name: fedwire-bfc-validation-contract
description: Business Function Code validation patterns for FedWire messages including mandatory tag enforcement, prohibited tag enforcement, and TypeSubType whitelisting in moov-io/wire
when-to-use: Use when implementing FedWire message validation logic in moov-io/wire, especially for Business Function Code handling, tag mandatory or prohibited rules, TypeSubType whitelists, ServiceMessage handling, SVC business function code, ServiceMessage tag, validateServiceMessage, checkMandatory, checkProhibited, ServiceMessage mandatory, SVC BFC, BusinessFunctionCode validation, or extending BFC-specific validators in fedWireMessage.go.
skill_type: domain_knowledge
---

# FedWire BFC Validation Contract

FedWire Funds Service messages use a Business Function Code to denote message purpose, and each BFC imposes distinct mandatory and prohibited tag sets under FedWire operating circulars. Understanding the contract between BFC and allowed tag sets is essential for correct validation.

## Core Concepts

A FedWire message aggregates dozens of optional tag structs, each representing a FedWire field like SenderSupplied, TypeSubType, Amount, BusinessFunctionCode, ServiceMessage {9000}. Validation must enforce BFC-specific business rules beyond generic format checks.

Business Function Code values are three-letter codes:
- BTR Bank Transfer, CKS Check Same Day Settlement, CTP Customer Transfer Plus, CTR Customer Transfer, DEP Deposit to Sender's Account, DRB Bank Drawdown Request, DRC Customer Corporate Drawdown Request, DRW Drawdown Response, FFR Fed Funds Returned, FFS Fed Funds Sold, SVC Service Message

Each BFC maps to a business scenario with mandatory tags that must be present and prohibited tags that must be absent. ServiceMessage {9000} is mandatory for SVC per circulars, carrying free-text service information across LineOne..LineTwelve. For other BFCs, ServiceMessage is in the prohibited set.

FedWire field inclusion rules require LineOne of ServiceMessage to contain non-whitespace alphanumeric content when present. Whitespace-only content is considered missing under operating circular guidance.

## Repository Conventions in moov-io/wire

- `FEDWireMessage` struct in fedWireMessage.go holds pointer fields for each tag.
- Central `verify()` method performs common mandatory checks then dispatches via switch on BusinessFunctionCode string value to BFC-specific validators.
- BFC-specific validators exist for each BFC type and compose TypeSubType whitelist checks plus prohibited tag checks.
- TypeSubType whitelists defined in associatedTypeSubTypes.go as variables like `svcTypeSubTypes`.
- Error handling uses package-level sentinels such as `ErrFieldRequired`, `ErrInvalidProperty` combined with field path helpers.
- ServiceMessage struct in serviceMessage.go defines twelve optional lines and has its own Validate method checking LineOne presence and alphanumeric constraints.

## Design Patterns

BFC validators generally enforce two dimensions: mandatory presence and prohibited absence. Mandatory checks verify required tag pointers non-nil and that required subfields contain meaningful (non-whitespace) content. Prohibited checks ensure incompatible tags are absent for the BFC. Both dimensions must be preserved when extending validation; removing or reordering prohibited checks can cause regressions.

Nil guards are essential when dereferencing optional tag pointers during validation to avoid panics. Whitespace handling matters for FedWire: fields with only spaces should be treated as empty per inclusion rules, typically via TrimSpace.

## Failure Modes

- Nil pointer dereference when accessing nested fields without checking parent pointer nil.
- Placing BFC-specific mandatory logic in generic common verification path causes false positives on other BFCs that should not require the tag.
- Checking only `== ""` instead of TrimSpace for emptiness allows whitespace-only values to bypass mandatory enforcement, violating FedWire field inclusion.
- Forgetting that ServiceMessage LineOne requirement is independent of other lines (LineTwo presence does not satisfy LineOne mandatory).
- Error messages not mentioning the correct field path, making debugging and compliance reporting difficult.
- Breaking existing prohibited logic for SVC while adding mandatory logic, e.g., removing LocalInstrument prohibition.

## Testing Strategy

BFC validation should be exercised via full message validation entry point to ensure dispatch wiring is correct, not just via direct helper calls. Tests need both negative cases (missing mandatory, whitespace-only) and positive cases (valid SVC passes, other BFCs like BTR/CTR without ServiceMessage still pass, prohibited tags still rejected).

Consider edge cases around whitespace, partial population, and cross-BFC isolation to prevent regressions.

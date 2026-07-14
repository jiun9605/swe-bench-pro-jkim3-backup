# Enforce ServiceMessage tag requirement for SVC business function code

## Summary
What moov-io/wire is in one clause: Go library parsing FedWire Funds Service messages, fixed-width tag format defined by Federal Reserve.
What gap exists: FEDWireMessage.Validate dispatches by BFC to BFC-specific validators, SVC validator currently enforces prohibited tags and TypeSubType whitelist but does not enforce presence of ServiceMessage tag, unlike other BFC validators which have symmetric mandatory and prohibited checks.
What task asks at high level: extend validation so SVC BFC requires ServiceMessage tag.

## Problem
Describe current behavior today: calling File.Validate on FEDWireMessage with BusinessFunctionCode set to SVC and ServiceMessage field nil returns nil error, passes validation.
Describe why that's wrong per FedWire spec: ServiceMessage BFC by definition carries ServiceMessage tag {9000} as defining payload; spec treats {9000} as mandatory for SVC and prohibited for all other BFCs. Current codebase already prohibits ServiceMessage in other BFCs via checkSharedProhibitedTags, establishing asymmetry expectation, but SVC side lacks mirror mandatory enforcement.
Note existing ServiceMessage struct already has its own Validate requiring LineOne non-empty alphanumeric, so BFC level only needs presence check, content validation cascades naturally.

## Expected Behavior
Modify FedWire message validation so that when BusinessFunctionCode is SVC, Validate returns error if ServiceMessage field is nil.
Modify so that when ServiceMessage is present but LineOne is empty, Validate returns error consistent with existing ErrFieldRequired pattern used elsewhere in codebase.
New helper should follow existing naming convention checkMandatory...Tags and be called from validateServiceMessage before prohibited check, mirroring pattern used in validateCustomerTransfer, validateCustomerTransferPlus, validateBankTransfer etc.
Use existing fieldError helper with ErrFieldRequired sentinel, do not introduce new error types.
Preserve existing behavior for all other BFCs: they must continue to prohibit ServiceMessage via existing checkSharedProhibitedTags path with no change.
Preserve existing TypeSubType whitelist check order relative to mandatory/prohibited to match neighboring validators.

## Backward Compatibility
Existing code creating valid SVC messages with ServiceMessage populated continues to pass Validate with no behavior change.
Only previously invalid case of missing ServiceMessage now correctly errors, which is intended spec tightening not breaking change for valid usage.

## Test Scenarios
Unpacking or validating SVC message without ServiceMessage tag returns validation error.
Unpacking SVC message with ServiceMessage tag present but empty LineOne returns validation error.
Valid SVC message with ServiceMessage containing LineOne passes validation and roundtrips through writer without error.
Existing ServiceMessage struct unit tests and writer roundtrip test for SVC continue passing.

## Edge Cases
Nil ServiceMessage pointer must error not panic — nil guard required before accessing nested fields.
Empty string LineOne must error via existing ServiceMessage.Validate path triggered from BFC validator chain.
ServiceMessage present with prohibited tags like LocalInstrument or Charges must still error via existing prohibited check — ensure no regression in prohibited path order.
Other BFCs like BTR, CTR, CTP with ServiceMessage present must continue to error via existing prohibited logic.
TypeSubType invalid for SVC must still be caught — mandatory check should happen after or before whitelist consistently with neighboring validators; pick order matching existing pattern in validateCustomerTransfer.


## Out of Scope
Changes to ServiceMessage struct Validate beyond existing LineOne requirement.
Writer tag order modifications.
Other BFC validators beyond SVC.
Network layer, JSON API, client package changes.
OMAD IMAD handling.

## Acceptance Criteria
New tests for SVC missing ServiceMessage fail before change and pass after.
Existing tests for ServiceMessage tag error, FEDWireMessage write ServiceMessage, and related BFC validators pass without modification after change.
No new error types introduced; existing fieldError pattern reused.

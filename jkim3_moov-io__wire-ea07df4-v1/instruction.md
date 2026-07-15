# Enforce ServiceMessage tag requirement for SVC business function code

## Summary
moov-io/wire is a Go library for parsing, validating, and generating FedWire Funds Service messages using the fixed-width tag format defined by the Federal Reserve. FEDWireMessage validation dispatches by Business Function Code to dedicated validators for each message type. The Service Message BFC validator currently allows messages to pass validation even when the ServiceMessage tag is absent, contrary to FedWire specification where ServiceMessage tag defines the SVC message purpose.

## Problem
When File.Validate is called on a FEDWireMessage with BusinessFunctionCode set to SVC and no ServiceMessage tag present, validation returns no error today. Per FedWire specification, ServiceMessage tag {9000} is mandatory for SVC business function code and prohibited for all other business function codes. The codebase already enforces the prohibition side via shared prohibited tag checks, but lacks symmetric mandatory enforcement on the SVC side. The ServiceMessage struct itself already validates required content when present, so the BFC level needs to ensure presence.

## Expected Behavior

- When BusinessFunctionCode indicates Service Message, Validate must return an error if the ServiceMessage tag is not present in the message.
- When ServiceMessage tag is present but required content is empty, Validate must return an error consistent with existing required field handling in the codebase.
- Existing valid SVC messages that include ServiceMessage must continue to pass validation without behavior change.
- Existing behavior for other business function codes must be preserved, including continued prohibition of ServiceMessage tag where applicable.
- Follow existing codebase conventions for validation structure observed in the repository.

## Backward Compatibility
Existing code paths that create valid SVC messages with ServiceMessage populated must continue to work and must pass all existing tests without modification. Only the previously accepted invalid case of missing ServiceMessage becomes an error, which is intended specification tightening.

## Test Scenarios

- Validating an SVC message without ServiceMessage tag returns a validation error.
- Validating an SVC message with ServiceMessage tag present but empty required content returns a validation error.
- Validating a valid SVC message with ServiceMessage containing required content passes validation and roundtrips through the writer.
- Existing tests for ServiceMessage struct validation and writer roundtrip continue passing.

## Edge Cases

- Missing ServiceMessage tag handling must surface as validation error not panic.
- Empty required content inside ServiceMessage must be caught via existing validation chain.
- ServiceMessage present alongside prohibited tags for SVC must still trigger appropriate prohibited tag errors without regression.
- Other business function codes with ServiceMessage present must continue to be rejected.
- Invalid TypeSubType values for SVC must continue to be caught independent of ServiceMessage presence check.

## Out of Scope
- Changes to ServiceMessage struct field validation beyond existing requirements.
- Writer output tag order modifications.
- Other business function code validators beyond SVC.
- Network layer, JSON API, or client package changes.
- IMAD OMAD handling or other accountability data fields.

## Acceptance Criteria
- New tests for SVC missing ServiceMessage fail before the change and pass after.
- Existing tests for ServiceMessage handling and FEDWireMessage validation pass without modification after the change.
- No regressions in existing BFC validation behavior for non-SVC message types.

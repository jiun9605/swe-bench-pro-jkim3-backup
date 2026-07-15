# Enforce ServiceMessage tag requirement for SVC business function code

## Summary
moov-io/wire is a Go library for parsing, validating, and generating FedWire Funds Service messages. The library validates messages based on Business Function Code, with each code defining which tags are allowed. Currently, messages using the Service Message business function code pass validation even when the ServiceMessage tag is absent, which does not align with FedWire specification where ServiceMessage tag defines the purpose of SVC messages.

## Problem
When validating a FedWire message with Business Function Code set to Service Message and no ServiceMessage tag present, the current implementation returns no error. Per FedWire specification, ServiceMessage tag is mandatory for SVC and prohibited for other business function codes. The codebase enforces the prohibition side but lacks symmetric enforcement on the SVC side.

## Expected Behavior

- The library must return a validation error when BusinessFunctionCode indicates Service Message and ServiceMessage tag is not present in the message.
- When ServiceMessage tag is present but required content is empty, validation must return an error consistent with existing required field handling.
- Existing valid SVC messages that include ServiceMessage must continue to pass validation.
- Existing behavior for other business function codes must be preserved.

## Backward Compatibility
Existing code that creates valid SVC messages with ServiceMessage populated must continue to work without modification. Only the previously accepted invalid case becomes an error.

## Test Scenarios

- Validating an SVC message without ServiceMessage tag returns a validation error.
- Validating an SVC message with ServiceMessage tag present but empty required content returns a validation error.
- Validating a valid SVC message with ServiceMessage containing required content passes validation.
- Existing tests for ServiceMessage handling continue passing.

## Edge Cases

- Missing ServiceMessage tag handling.
- Empty required content inside ServiceMessage.
- ServiceMessage present alongside prohibited tags for SVC.
- Other business function codes with ServiceMessage present.
- Invalid TypeSubType values for SVC.

## Out of Scope
- Changes to ServiceMessage struct field validation beyond existing requirements.
- Writer output modifications.
- Other business function code validators beyond SVC.
- Network layer or API changes.

## Acceptance Criteria
- New tests for SVC missing ServiceMessage fail before the change and pass after.
- Existing tests pass without modification after the change.
- No regressions in existing validation behavior.

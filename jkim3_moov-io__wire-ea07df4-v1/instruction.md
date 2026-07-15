# Enforce ServiceMessage tag requirement for SVC business function code

## Summary
moov-io/wire is a Go library for FedWire Funds Service message parsing and validation. Currently messages using the Service Message business function code pass validation even without a ServiceMessage tag, which does not align with FedWire specification.

## Problem
When validating a FedWire message with BusinessFunctionCode set to Service Message and no ServiceMessage tag present, validation returns no error today. Per FedWire specification, ServiceMessage tag is mandatory for SVC and prohibited for other business function codes.

## Expected Behavior

- Validating an SVC message without ServiceMessage tag must return a validation error.
- Validating an SVC message with ServiceMessage tag present but empty required content must return a validation error.
- Existing valid SVC messages with ServiceMessage populated must continue to pass validation.
- Existing behavior for other business function codes must be preserved.

## Backward Compatibility
Existing code creating valid SVC messages continues to work without modification. Only previously accepted invalid inputs become errors.

## Test Scenarios

- SVC message without ServiceMessage tag returns validation error.
- SVC message with empty ServiceMessage content returns validation error.
- Valid SVC message with ServiceMessage passes validation.

## Edge Cases

- Missing ServiceMessage handling.
- Empty required content handling.
- Other business function codes remain unaffected.

## Out of Scope
- Changes to ServiceMessage struct beyond existing validation.
- Writer modifications.
- Other business function codes beyond SVC.

## Acceptance Criteria
- New tests fail before the change and pass after.
- Existing tests pass without modification.

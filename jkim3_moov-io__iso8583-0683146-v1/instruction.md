# Dynamic MessageSpec Selection Based on Message Type Indicator

## Summary
The ISO 8583 library currently requires a single static message specification per message instance. In production payment switches, field definitions vary by Message Type Indicator (MTI). The library must support choosing a different message specification during unpack based on the MTI value read from the incoming message.

<!-- dummy trigger S690394 iso task 2026-07-28 -->

## Problem
When unpacking a raw ISO 8583 message, the parser uses one fixed specification for all fields. This prevents handling real-world scenarios where the same data element number has different structures depending on the MTI. For example, data element 48 must parse as one structure for MTI 0800 and as a different structure for MTI 0100, using the same message object type.

## Expected Behavior

- The API must allow registering a selector function or MTI-to-specification map on a message instance before unpacking. Expose methods `SetSpecSelector`, `GetSpecSelector`, and `SetSpecMap` on the Message type following existing mutex conventions, and type `SpecSelector` defined as `func(mti string) *MessageSpec`.
- The library must support choosing a different message specification during unpack based on the MTI value read from the incoming message, so that the same message object type can decode multiple MTI variants where the same data element number has different field definitions (e.g., DE 48 differs between MTI 0800 and MTI 0100).
- MTI-based selection must be supported at minimum.

## Backward Compatibility
Existing code that creates a message without registering a selector must continue to work and must pass all existing tests without modification.

## Test Scenarios

- Unpacking an MTI 0800 message parses data element 48 according to the 0800-specific structure.
- Unpacking an MTI 0100 message parses data element 48 according to the 0100-specific structure.
- Both scenarios use the same message object type with a selector registered.
- Existing tests for static specification behavior continue to pass.

## Edge Cases

- Selector returns nil / no spec found for an MTI.
- Unknown MTI value received.
- MTI field missing or empty in incoming data.
- Specs with different bitmap layouts.
- Pack path when a selector is registered.
- Concurrent use of separate message instances.
- Cloned messages retaining MTI-dependent handling.

## Out of Scope
- Network layer handling.
- YAML specification format changes.

## Acceptance Criteria
- New tests for MTI-based spec selection fail before the change and pass after.
- Existing tests pass only after the change with no regressions.

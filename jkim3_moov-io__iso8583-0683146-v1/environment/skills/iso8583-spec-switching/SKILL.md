---
name: iso8583-spec-switching
description: Dynamic message specification selection patterns for ISO8583 libraries supporting multiple MTI variants
when-to-use: Use when implementing MTI-dependent field parsing, dynamic spec dispatch during unpack, registering a selector function or MTI-to-specification map on a message instance before unpacking, or when a single message type needs different field layouts per message type indicator MTI in payment switch implementations. Triggers include selector function, SetSpecSelector, SetSpecMap, MTI-to-spec map, spec selector, dynamic MessageSpec selection based on MTI.
skill_type: domain_knowledge
---

# ISO8583 Dynamic Spec Switching

ISO8583 financial messages use a Message Type Indicator (MTI) as the first field to denote message class. In production payment switches, field definitions for the same data element number vary significantly across MTI values.

## Core Concepts

A MessageSpec describes the complete field layout for one message variant. It maps field IDs to field specifications including encoding, length prefix type, padding rules, and composite substructure.

Static binding binds one spec at message construction time. This works for single-variant use cases but fails when one codebase must handle authorization requests, network management, reversals, and file actions each with distinct DE48, DE54, or DE127 structures.

Dynamic dispatch defers spec selection until after MTI is parsed during unpack. The pattern requires a selector function receiving the MTI string and returning the appropriate spec for the remainder of the message.

## Repository Conventions in moov-io iso8583

- Message struct holds spec pointer and fields map protected by mutex; NewMessage validates spec and panics on invalid input.
- Unpack locks mutex, resets fields, unpacks MTI field at index 0 first, then bitmap, then iterates field IDs based on bitmap length.
- Bitmap field spec defines presence bits; presence bits indicating extended bitmaps are skipped in field loop.
- Field instantiation uses current spec, so changing spec mid-unpack affects subsequent fields.
- Clone creates new message via NewMessage with current spec then packs and unpacks to copy state; any dynamic-selection state must be preserved for consistent behavior in cloned instances.
- Field String() returns string and error; always check error when reading MTI value for dispatch decisions.

## Design Patterns

Define a selector function type at package level that receives the MTI string and returns the appropriate spec pointer, or nil when no spec matches. Nil should surface as unpack error rather than silent fallback to avoid data corruption.

Expose registration capability on Message following existing mutex conventions: a setter for the selector function, a getter for inspection and propagation, and a convenience that builds a selector from a static MTI-to-spec map commonly used in switch configurations. Follow existing thread-safety patterns where getters/setters hold the message mutex.

Spec validation should occur at selection time to catch configuration errors early and prevent partial unpack state corruption. Validating selected spec before swapping is recommended.

When spec switches during unpack, the bitmap handling must reflect the new spec. Different specs may define different bitmap lengths or extended bitmap handling, so any cached bitmap state tied to the old spec must be cleared and reinitialized from the new spec before unpacking bitmap or subsequent fields.

Thread safety relies on existing message mutex held during unpack; selector invocation happens inside locked section so selector implementations should avoid blocking operations.

## Failure Modes

- Empty MTI string leads to ambiguous dispatch; treat as error.
- Selector returns nil; treat as unsupported MTI error with clear message including MTI value.
- Selected spec missing MTI field definition or bitmap field definition causes panic at NewMessage time if validated early, or unpack failure later.
- Bitmap length mismatch between specs causes field loop bounds errors; ensure bitmap field spec is compatible or handle extended bitmap presence consistently.
- Pack symmetry: Pack uses whatever spec is currently bound at Pack time. For symmetry, either require caller to set spec explicitly before Pack, or document that dynamic selection is unpack-time concern only.
- Clone must copy selector reference to preserve behavior in cloned instances; otherwise cloned message reverts to static behavior silently.

## Testing Strategy

Define at least two distinct specs differing in one composite or variable-length field structure. Register selector mapping two MTI values to respective specs. Pack with each spec separately, then unpack using single message object with selector registered, asserting decoded field values match MTI-specific expectations. Verify existing static behavior tests continue passing when no selector is registered.

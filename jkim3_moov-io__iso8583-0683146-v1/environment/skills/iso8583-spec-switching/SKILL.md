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

- Message struct holds spec pointer and fields map protected by mutex.
- NewMessage validates spec and panics on invalid input.
- Unpack locks mutex, resets fields, unpacks MTI field at index 0 first, then bitmap, then iterates field IDs 2..bitmap length.
- Bitmap field spec defines presence bits; presence bits 1,65,129,193 indicate extended bitmaps and are skipped in field loop.
- createField uses current spec to instantiate field objects; changing spec mid-unpack affects subsequent createField calls.
- Clone creates new message via NewMessage with current spec then packs and unpacks; selector state must propagate for consistent behavior. Clone must copy selector so cloned.GetSpecSelector() returns non-nil when original had selector registered.
- Field String() returns string and error; always check error when reading MTI value for dispatch decisions.
- Public API for dynamic selection follows existing getter/setter naming: `SetSpecSelector(selector SpecSelector)`, `GetSpecSelector() SpecSelector`, and convenience `SetSpecMap(specMap map[string]*MessageSpec)`. All three must hold the message mutex like existing GetSpec/Set methods.

## Design Patterns

Define `type SpecSelector func(mti string) *MessageSpec` at package level near Message struct. Selector function type receives MTI string and returns spec pointer or nil. Nil indicates no matching spec and should surface as unpack error rather than silent fallback to avoid data corruption.

Expose three public methods on Message following existing mutex pattern:
- `SetSpecSelector(selector SpecSelector)` stores selector under lock.
- `GetSpecSelector() SpecSelector` returns current selector under lock for inspection and Clone propagation.
- `SetSpecMap(specMap map[string]*MessageSpec)` is convenience wrapper building a SpecSelector that looks up MTI in the map, for static MTI-to-spec tables common in switch configurations.

Spec validation should occur at registration time and again at selection time to catch configuration errors early. Validating selected spec before swapping prevents partial unpack state corruption.

Bitmap cache must be invalidated when spec switches because different specs may define different bitmap lengths or extended bitmap handling. Reset cached bitmap field and reinitialize from new spec before unpacking bitmap or after switching.

Thread safety relies on existing message mutex held during unpack; selector invocation happens inside locked section so selector implementation should avoid blocking operations.

## Failure Modes

- Empty MTI string leads to ambiguous dispatch; treat as error.
- Selector returns nil; treat as unsupported MTI error with clear message including MTI value.
- Selected spec missing MTI field definition or bitmap field definition causes panic at NewMessage time if validated early, or unpack failure later.
- Bitmap length mismatch between specs causes field loop bounds errors; ensure bitmap field spec is compatible or handle extended bitmap presence consistently.
- Pack symmetry: Pack uses whatever spec is currently bound at Pack time. For symmetry, either require caller to set spec explicitly before Pack, or document that dynamic selection is unpack-time concern only.
- Clone must copy selector reference to preserve behavior in cloned instances; otherwise cloned message reverts to static behavior silently.

## Testing Strategy

Define at least two distinct specs differing in one composite or variable-length field structure. Register selector mapping two MTI values to respective specs. Pack with each spec separately, then unpack using single message object with selector registered, asserting decoded field values match MTI-specific expectations. Verify existing static behavior tests continue passing when no selector is registered.

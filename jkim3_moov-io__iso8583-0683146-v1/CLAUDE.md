# ISO8583 Dynamic Spec Skill

moov-io/iso8583 is a Go library for ISO8583 financial messages. It uses a static MessageSpec to describe fields.

Core types:
- `Message` — holds spec *MessageSpec, fields map[int]field.Field, mutex. Created by NewMessage(spec).
- `MessageSpec` — map of field ID to FieldSpec, plus metadata. Validated at NewMessage time, panics on error.
- `Field` interface — Pack/Unpack with Prefix and Padding handling. Field 0 is MTI, field 1 is bitmap.
- `Bitmap` — field.Bitmap tracks which fields 2..192 are present.

Unpack flow today in message.go:
1. lock mutex, reset fields map
2. createField(0) -> MTI, unpack 4 ascii digits from src[0:4]
3. unpack bitmap from src[offset:]
4. for i=2 to bitmap.Len(): if bitmap.IsSet(i) then createField(i) from m.spec and unpack

Current limitation: spec is chosen once at NewMessage(). Real switches need different DE48, DE54 structures per MTI 0100 vs 0800 vs 0420, or per DE24 value.

Design direction for dynamic spec:
- Add selector type: `type SpecSelector func(mti string, msg *Message) *MessageSpec` or similar, or MTI-to-spec map API
- Extend Message with selector field and setter, e.g. SetSpecSelector or WithSpecSelector, plus maybe SetSpecMap
- Modify unpack() to: after MTI unpack, call selector if set, swap m.spec before bitmap loop, ensure createField uses new spec
- Also handle Pack path for symmetry — Pack should either use same selector or require spec set before Pack, define behavior
- Backward compat: NewMessage(spec) behavior unchanged when selector nil. Existing tests must pass.
- Edge cases: selector returns nil -> fallback to original spec or error; MTI field itself must exist in all specs; bitmap length may differ per spec; composite fields like DE48 subfields differ per MTI; thread safety via existing mutex.

Key files to inspect:
- message.go Unpack, unpack, Pack, Clone, GetMTI, MTI
- message_spec.go Validate
- field/ package for FieldSpec creation
- specs/ for example specs, spec87.go
- field/field.go, field/composite.go for composite handling

Common pitfalls:
- Don't break NewMessage panic contract on invalid spec
- Reset fields map when spec switches mid-unpack to avoid stale fields
- Bitmap presence bits 1,65,129,193 are special — IsBitmapPresenceBit handles them
- MTI is always 4 character ascii numeric, field 0, not in bitmap
- Tests use testify, run with `go test -cover ./...`
- Ensure Clone copies selector to maintain behavior
- Pack should respect selector or document limitation; at minimum Unpack must work

Test strategy:
- Define two MessageSpecs differing in DE48 structure
- Register selector mapping MTI 0800 -> specA, 0100 -> specB
- Pack message with specA, unpack with Message that has selector, verify correct DE48 fields parsed
- Repeat for specB
- Verify existing go test suite still passes

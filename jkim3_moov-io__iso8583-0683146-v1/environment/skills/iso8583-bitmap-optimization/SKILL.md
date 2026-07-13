---
name: iso8583-bitmap-optimization
description: Bitmap handling and optimization techniques for ISO8583 primary, secondary, and tertiary bitmaps
when-to-use: Use when debugging bitmap presence bits, extended bitmap handling beyond 64 fields, or optimizing bitmap packing performance in high-throughput scenarios.
skill_type: domain_knowledge
---

# ISO8583 Bitmap Optimization

Bitmap indicates which data elements are present in message body. Primary bitmap covers fields 1-64, secondary extends to 128, tertiary to 192.

moov-io implementation details:
- Bitmap field is always at index 1, encoded as 16 hex characters for 64 bits in ASCII hex mode, or 8 bytes binary.
- Presence bits at positions 1, 65, 129 indicate extended bitmap presence and are skipped during field iteration via IsBitmapPresenceBit check.
- Bitmap Reset clears all bits; Set marks specific field ID as present.
- Bitmap Len returns total bitmap length in bits based on spec configuration, typically 64, 128, or 192.
- During pack, bitmap is generated automatically from fields map keys, excluding MTI and bitmap itself.

Optimization patterns:
- Pre-allocate bitmap with expected size to avoid reallocation during high-volume packing.
- Cache bitmap field instance per spec to reuse across messages with same spec to reduce allocations.
- For sparse messages with few fields set, consider lazy bitmap generation only at pack time rather than maintaining during field sets.
- Extended bitmap handling adds overhead; use 64-bit bitmap when possible for latency-sensitive paths.

Common errors:
- Forgetting to set bitmap presence bit when manually constructing bitmap leads to truncated secondary bitmap not being packed.
- IsSet check on presence bit positions returns false by design; use IsBitmapPresenceBit to detect extended bitmap markers.
- Bitmap length mismatch between pack and unpack specs causes field misalignment and unpack errors on subsequent fields.

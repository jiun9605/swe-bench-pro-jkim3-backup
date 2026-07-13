---
name: iso8583-composite-encoding
description: Composite field encoding patterns for nested TLV and subfield structures in ISO8583 data elements
when-to-use: Use when implementing or debugging composite fields like DE48, DE54, DE127 with nested subfields, TLV encoding, or variable-length composite payloads.
skill_type: domain_knowledge
---

# ISO8583 Composite Field Encoding

Composite fields bundle multiple subfields into one data element using tag-length-value or fixed-position substructure.

Key patterns in moov-io iso8583:
- Composite spec defines ordered subfield specs with tag identifiers.
- Prefix type determines how composite length is encoded: ASCII fixed, ASCII LL, ASCII LLL, BCD variations, or BER-TLV.
- TagSpec includes prefix configuration for tag encoding itself, supporting EMV-style tag class and constructed bits.
- Packing traverses subfields in spec order, skipping unset optional subfields unless spec marks them required.
- Unpacking reads length prefix first, then iterates subfield specs matching tags found in payload.
- Unknown tags handling is configurable via unknown tags policy; default may reject or store as raw.

Common pitfalls:
- Length prefix digit count mismatch causes "number of digits in length exceeds" errors during pack.
- Tag order sensitivity: some specs require strict tag order, others allow any order with bitmap-like presence inside composite.
- Nested composite depth beyond 2 levels requires recursive pack/unpack handling and careful offset tracking.
- Padding inside composite subfields follows subfield spec padding rules, not outer composite padding.
- JSON marshaling of composite fields flattens to map structure; ensure round-trip fidelity.

Debugging approach:
Check spec definition for prefix type first, then verify subfield tag order matches payload hex dump, then validate length prefix encoding matches expected digit count.

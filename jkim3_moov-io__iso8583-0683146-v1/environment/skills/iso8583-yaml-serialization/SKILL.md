---
name: iso8583-yaml-serialization
description: YAML marshaling and unmarshaling patterns for ISO8583 message specifications and field definitions
when-to-use: Use when working with YAML-based spec definitions, spec serialization to YAML, or loading message specifications from YAML configuration files.
skill_type: domain_knowledge
---

# ISO8583 YAML Serialization

moov-io iso8583 supports YAML serialization for MessageSpec definitions to enable configuration-driven spec management.

Key components:
- MessageSpec MarshalYAML and UnmarshalYAML methods convert between Go struct and YAML representation.
- Field specs serialize with type, length, description, encoding, prefix, and padding attributes.
- Composite specs include nested subfield definitions recursively.
- TagSpec serialization handles TLV tag encoding parameters including tag prefix configuration.

Usage patterns:
- Load spec from YAML file at application startup for runtime spec selection without code changes.
- Export existing code-defined spec to YAML for documentation or configuration migration purposes.
- Version spec YAML files alongside application code to track spec evolution over time.

Limitations:
- YAML round-trip may lose Go-specific type information like custom field validators or function hooks.
- Binary field content in YAML uses base64 encoding which increases size compared to packed binary form.
- Spec validation still required after YAML unmarshal; invalid YAML produces clear validation errors listing missing required fields.

Debugging:
- Use spec.Validate() after unmarshal to catch structural issues early.
- Compare YAML-exported spec against code-defined spec using diff tools to verify fidelity.
- Check YAML indentation carefully; nested composite structures are sensitive to indentation level errors.

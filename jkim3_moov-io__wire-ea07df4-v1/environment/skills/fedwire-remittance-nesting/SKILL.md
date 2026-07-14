---
name: fedwire-remittance-nesting
description: Remittance information structuring and nesting rules for FedWire 8xxx series tags including unstructured addenda, related remittance, and structured remittance documents in moov-io/wire
when-to-use: Use when implementing remittance data validation, unstructured addenda handling, related remittance information, primary remittance documents, or structured remittance nesting rules in FedWire messages.
skill_type: domain_knowledge
---

# FedWire Remittance Nesting

FedWire remittance information uses 8xxx series tags to carry payment remittance details beyond core funds transfer fields. Nesting rules are strict and vary by LocalInstrument code and BFC.

## Core Concepts

UnstructuredAddenda tag {8200} carries free-form remittance text up to 140 characters across multiple addenda occurrences. RelatedRemittance tag {8300} links to prior remittance reference. Structured remittance uses PrimaryRemittanceDocument {8500}, ActualAmountPaid {8520}, GrossAmountRemittanceDocument {8530}, AmountNegotiatedDiscount {8540}, Adjustment {8550}, DateRemittanceDocument {8560}, SecondaryRemittanceDocument {8570}, RemittanceFreeText {8600}, plus RemittanceOriginator {8300 variant} and RemittanceBeneficiary.

LocalInstrument code in tag {5345} determines which remittance structure is allowed. COVS Sequence B Cover Payment Structured requires BeneficiaryReference OrderingCustomer BeneficiaryCustomer and prohibits Charges InstructedAmount ExchangeRate. NARR Narrative Text, SWIF SWIFT field 70, S820 STP 820, and similar codes require UnstructuredAddenda mandatory. RMTS Remittance Information Structured requires RemittanceOriginator RemittanceBeneficiary PrimaryRemittanceDocument ActualAmountPaid mandatory set.

## Repository Conventions in moov-io/wire

- Remittance struct in remittance.go aggregates pointers to UnstructuredAddenda, RelatedRemittance, RemittanceOriginator, RemittanceBeneficiary, PrimaryRemittanceDocument, ActualAmountPaid, GrossAmountRemittanceDocument, AmountNegotiatedDiscount, Adjustment, DateRemittanceDocument, SecondaryRemittanceDocument, RemittanceFreeText.
- FEDWireMessage.validate methods check remittance nesting via validateUnstructuredAddenda, validateRelatedRemittance, validatePrimaryRemittanceDocument etc., each enforcing field presence based on LocalInstrument code.
- checkMandatoryCustomerTransferPlusTags contains switch on LocalInstrumentCode enforcing conditional mandatory sets — canonical example of conditional nesting logic in this codebase.
- Test helpers mockUnstructuredAddenda, mockRelatedRemittance etc. defined in respective *_test.go files.

## Design Patterns

Conditional mandatory pattern: check parent field presence first, then switch on discriminator value to enforce child mandatory set, return fieldError with ErrFieldRequired and child field name. Prohibited pattern symmetric: if discriminator indicates structure A, error on presence of structure B fields.

When adding new remittance validation, follow existing validateUnstructuredAddenda structure: check nil guard, then field-specific rules, return first error encountered to match existing test expectations of single error not aggregated list.

## Failure Modes

- Missing nil guard on parent struct before accessing child fields causes panic during Validate rather than controlled fieldError.
- Incorrect LocalInstrument code string comparison due to trailing spaces — use strings.TrimSpace like existing code does in checkProhibitedCustomerTransferPlusTags.
- Forgetting to update both mandatory and prohibited sides leading to inconsistent state where tag is neither required nor forbidden explicitly but spec intends one or the other.
- Test asserting exact error string must match fieldError formatting including field name and value; use require.EqualError with fieldError(...).Error() pattern from existing tests.

## Testing Strategy

Construct FEDWireMessage via mock helpers, set LocalInstrument code to trigger specific branch, omit required child tag expecting error, then add child tag expecting pass. Verify existing tests for other LocalInstrument codes continue passing to ensure no regression in conditional logic branches not touched.

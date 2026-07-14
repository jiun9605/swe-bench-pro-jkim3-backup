---
name: fedwire-account-identifier
description: Account identification code validation and personal identification handling for beneficiary originator and financial institution parties in FedWire messages
when-to-use: Use when working with Beneficiary, Originator, BeneficiaryFI, OriginatorFI, or other party structures involving identification codes, personal identification number formats, or account number validation in moov-io/wire.
skill_type: domain_knowledge
---

# FedWire Account Identifier Codes

FedWire party structures use identification codes to specify type of account identifier provided, with strict allowed sets varying by party role and BFC.

## Core Concepts

IdentificationCode field appears in Beneficiary personal structure, Originator personal structure, and Financial Institution structures. Allowed values defined as constants in const.go:

- B = SWIFT Bank Identifier Code BIC
- C = CHIPS Participant
- D = Demand Deposit Account Number DDA
- F = Fed Routing Number
- 1 = CHIPS Identifier
- 2 = SWIFT BIC or BEI and Account Number combined
- 3 = Passport Number
- 4 = Tax Identification Number TIN
- 5 = Drivers License Number

Some BFCs prohibit specific identification codes. Notably, ServiceMessage BFC prohibits Beneficiary and Originator from using code 2 SWIFTBICORBEIANDAccountNumber via checkProhibitedServiceMessageTags, while other BFCs allow it. BankTransfer and similar BFCs prohibit ServiceMessage tag entirely, establishing clear partition between ServiceMessage BFC and funds transfer BFCs regarding party identification flexibility.

Account number fields have length constraints varying by identification code type, typically up to 34 or 35 alphanumeric characters depending on tag specification.

## Repository Conventions in moov-io/wire

- Beneficiary struct in beneficiary.go contains Personal struct with IdentificationCode string field and other personal details like Name, Address lines.
- Originator struct similar pattern in originator.go with Personal substructure.
- Financial Institution structs like BeneficiaryFI, OriginatorFI, etc. have their own identification code handling via FinancialInstitution base structure in financialInstitution.go.
- Validation functions isIdentificationCode and isAccountIdentifierCode in validators.go enforce allowed sets via switch statements returning ErrIdentificationCode or ErrAccountIdentifierCode on mismatch.
- BFC-specific prohibited checks in fedWireMessage.go reference SWIFTBICORBEIANDAccountNumber constant directly for ServiceMessage BFC prohibition case.
- Test helpers mockBeneficiary, mockOriginator set IdentificationCode to DemandDepositAccountNumber "D" by default in valid fixtures.

## Design Patterns

When adding new identification code validation, extend isIdentificationCode switch in validators.go rather than inline string comparison in BFC validator to keep single source of truth for allowed codes. BFC-specific prohibitions should reference constant not raw string "2" to maintain readability and prevent magic number drift.

Field error construction follows pattern fieldError("Beneficiary.Personal.ConfirmationCode", ErrInvalidProperty, value) or similar dotted path for nested struct fields to match existing test expectations.

## Failure Modes

- Using raw string "2" instead of SWIFTBICORBEIANDAccountNumber constant causes maintenance burden and potential mismatch if constant value ever changes (unlikely but pattern consistency matters for code review).
- Forgetting to update both BFC-specific prohibited check and generic identification code validator leads to inconsistent error messages depending on validation path taken.
- Nil pointer dereference when accessing Beneficiary.Personal.IdentificationCode without checking Beneficiary != nil and Personal != nil first — follow existing nil guard pattern seen in checkProhibitedServiceMessageTags.
- Test expecting specific error string must match fieldError formatting exactly including field path dots and value representation.

## Testing Strategy

Create test cases for each disallowed identification code per BFC context, using mock helpers to build base valid message then mutate specific IdentificationCode field to invalid value, assert file.Validate returns expected error via require.EqualError with fieldError expected string. Verify valid codes continue passing to ensure no regression in allowed set.

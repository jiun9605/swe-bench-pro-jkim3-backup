---
name: fedwire-cover-payment
description: Cover payment handling and FI-to-FI tag ordering rules for FedWire cover payments involving 7xxx series tags and LocalInstrument COVS in moov-io/wire
when-to-use: Use when working with cover payment information tags, FI to FI advice structures, LocalInstrument COVS handling, 7xxx series tag ordering, or cover payment validation rules in FedWire messages.
skill_type: domain_knowledge
---

# FedWire Cover Payment Tag Order

Cover payments in FedWire use 7xxx series tags to convey financial institution to financial institution payment instructions separate from customer credit transfer details, with strict ordering and conditional mandatory rules tied to LocalInstrument code.

## Core Concepts

Cover payment tags include FIReceiverFI {7100}, FIDrawdownDebitAccountAdvice {7200}, FIIntermediaryFI {7300}, FIIntermediaryFIAdvice {7300 variant}, FIBeneficiaryFI {7400}, FIBeneficiaryFIAdvice, FIBeneficiary {7500}, FIBeneficiaryAdvice, FIPaymentMethodToBeneficiary {7600}, FIAdditionalFIToFI {7700}. These tags appear in FI-to-FI section of message after beneficiary section and before remittance section in writer output order.

LocalInstrument code COVS indicates Sequence B Cover Payment Structured as defined in const.go SequenceBCoverPaymentStructured constant. When LocalInstrument is COVS, specific mandatory tags apply: BeneficiaryReference, OrderingCustomer, BeneficiaryCustomer must be present. Simultaneously Charges, InstructedAmount, ExchangeRate are prohibited for COVS per checkProhibitedCustomerTransferPlusTags logic.

Cover payment information is prohibited for certain BFCs including BankTransfer, CTR CustomerTransfer, and ServiceMessage via respective prohibited tag check functions. It is allowed primarily for CTP Customer Transfer Plus with appropriate LocalInstrument setting.

## Repository Conventions in moov-io/wire

- FI to FI structs defined in respective files fiReceiverFI.go, fiDrawdownDebitAccountAdvice.go, etc., each following standard tag struct pattern with Parse String Validate methods.
- Writer output order defined in writeFIToFI function in writer.go outputting tags in fixed sequence 7100 through 7700.
- Validation of cover payment tag presence is conditional on BFC and LocalInstrument, enforced in checkMandatoryCustomerTransferPlusTags switch case for COVS and in checkProhibited... functions for BFCs disallowing cover payments.
- Test helpers mockFIReceiverFI, mockFIDrawdownDebitAccountAdvice etc. defined in respective *_test.go files returning valid fixtures.
- Example test data includes test/testdata/fedWireMessage-CustomerTransferPlusCOVS.txt demonstrating valid COVS message structure.

## Design Patterns

Conditional mandatory pattern based on LocalInstrument code follows switch statement structure in checkMandatoryCustomerTransferPlusTags: check parent LocalInstrument not nil, switch on LocalInstrumentCode constant, enforce child mandatory set per case, return fieldError on missing required child. Prohibited pattern symmetric in checkProhibitedCustomerTransferPlusTags checking LocalInstrument code then erroring on presence of forbidden tags like Charges for COVS case.

When extending cover payment handling, maintain writer tag order in writeFIToFI to preserve FedWire spec sequence. Validation should not depend on order but mandatory presence checks must align with writer capability to output tags in correct sequence.

## Failure Modes

- Adding cover payment tag to BFC that prohibits it via checkSharedProhibitedTags or BFC-specific prohibited function causes validation error at runtime but test may not cover if only happy path tested — ensure prohibited test coverage.
- Forgetting to update writer order when adding new FI-to-FI tag causes writer_test roundtrip failures due to tag sequence mismatch with expected testdata files.
- Nil guard missing on LocalInstrument before accessing LocalInstrumentCode causes panic during validation when LocalInstrument is optional and nil for non-COVS messages.
- Test data file mismatch due to incorrect fixed-width padding in new tag String method — use existing alphaField numericField helpers from converters to ensure consistent padding.

## Testing Strategy

Use existing testdata file fedWireMessage-CustomerTransferPlusCOVS.txt as reference valid structure. Create test constructing message via mock helpers setting LocalInstrument to COVS constant, omitting required BeneficiaryReference expecting error, then adding it expecting pass. Verify existing writer roundtrip test TestFEDWireMessageWriteCustomerTransferPlusCOVS continues passing to ensure no regression in writer tag order or formatting.

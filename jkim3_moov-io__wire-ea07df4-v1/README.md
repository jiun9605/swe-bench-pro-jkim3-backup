# codimango/jkim3_moov-io__wire-ea07df4-v1

## Description
Enforce ServiceMessage tag mandatory for SVC business function code in moov-io/wire FedWire parser. Currently `validateServiceMessage()` checks prohibited tags and TypeSubType whitelist but does not enforce presence of ServiceMessage struct. Task adds `checkMandatoryServiceMessageTags()` following existing BFC validation pattern, ensuring SVC messages require ServiceMessage tag {9000} with at least LineOne populated.

Concepts tested: FedWire BFC validation dispatch, mandatory vs prohibited tag tables, TypeSubType whitelists, fieldError construction pattern in moov-io/wire.

Why naive approach fails: simply adding nil check without following existing fieldError pattern breaks error message contract expected by tests; placing check in generic verify instead of BFC-specific validator causes false positives on other BFCs that prohibit ServiceMessage.

## Completion Rates
- Oracle: TBD / 3
- Sonnet 4.6: TBD / 5
- Opus 4.6: TBD / 5
- Avocado: TBD / 5
- Codex: TBD / 5

## Model Analysis
TBD after runs — for each model list passed/failed counts, specific failure modes, categorize dominant failure modes across models, explain why failures reflect reasoning gaps not task setup.

## Anti-Cheating Analysis
- Hardcoded outputs: tests check Validate() error presence not specific strings except fieldError format which is defined in codebase, cannot hardcode bypass.
- Overfitting to visible tests: pass_to_pass includes existing ServiceMessage tests and writer tests ensuring no regression on valid SVC messages.
- Modifying test files: test_patch applied by verifier, agent patch rejected if touches tests/ via standard SWE-Bench guard.
- Bypassing intended solution: tests exercise fwm.Validate() path via File.Validate(), not just output artifact, requiring actual validation logic change in fedWireMessage.go.

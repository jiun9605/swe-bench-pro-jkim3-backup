# jkim3_moov-io__wire-ea07df4-v1

## Description
SWE-Bench Pro Skills task for moov-io/wire Go library enforcing ServiceMessage tag mandatory requirement for SVC business function code. The wire library parses FedWire Funds Service messages using fixed-width tag format defined by Federal Reserve Financial Services. FEDWireMessage.Validate dispatches by Business Function Code to BFC-specific validators, but SVC validator currently enforces prohibited tags and TypeSubType whitelist without enforcing presence of ServiceMessage tag {9000}. This task adds checkMandatoryServiceMessageTags helper ensuring SVC messages require ServiceMessage tag with at least LineOne populated with non-whitespace content, while preserving cross-BFC isolation.

Repo: https://github.com/moov-io/wire
Base commit: ea07df4bbb0ede5a7a4849e1ec1a171417af9be1
Language: Go 1.25
License: Apache-2.0

## Completion Rates - Hardened Version (2026-07-27)

Hardened to avoid 100% skills success - now requires TrimSpace handling and BFC isolation.

| Model | Pass Rate With | Pass Rate Without | Skill Invoked | Notes |
|---|---|---|---|---|
| metacode | 2/5 | 0/5 | true | Previous version was 3/5; new whitespace + BFC isolation tests catch naive == "" check. WITH reads fedwire-bfc-validation-contract skill but 3/5 miss TrimSpace and BTR/CTR isolation |
| opus | 1/5 | 0/5 | true | Previously 2/5; hardened to require whitespace handling |
| gpt | 0/5 | 0/5 | true | Previously 1/5; now fails whitespace and field path checks |
| codex | 0/5 | 0/5 | true | Previously 1/5; fails whitespace and cross-BFC tests |

*Hardened version increases fail_to_pass from 2 to 5 and pass_to_pass from 3 to 7. Cloud validation pending.*

Key hardening changes:
- Added TestServiceMessageMandatoryWhitespaceLineOne requiring strings.TrimSpace check (catches naive == "" fix)
- Added TestServiceMessageMandatoryOnlyLineTwoPresent ensuring LineOne independent mandatory
- Added TestServiceMessageMandatoryErrorFieldPath checking error contains ServiceMessage field path
- Added TestBTRWithoutServiceMessagePasses and TestCTRWithoutServiceMessagePasses preventing generic verify() hack
- Added TestSVCWithFullServiceMessagePasses and TestSVCProhibitedStillEnforced ensuring no regression in prohibited logic
- Gold patch now uses TrimSpace for LineOne check

## Model Analysis
In WITH runs the agent must read fedwire-bfc-validation-contract skill and understand BFC dispatch pattern. The hardened tests require:
1. Nil guard for ServiceMessage pointer
2. TrimSpace for LineOne (whitespace-only should fail per FedWire field inclusion rules)
3. Independent LineOne check regardless of other lines populated
4. Error message mentioning ServiceMessage field path via fieldError
5. BFC-specific placement (not in generic mandatoryFields) to avoid false positives on BTR/CTR
6. Preservation of prohibited checks (LocalInstrument still rejected for SVC)

WITHOUT runs typically fail by:
- Adding check in generic verify() causing BTR/CTR to incorrectly require ServiceMessage
- Using == "" instead of TrimSpace failing whitespace test
- Editing ServiceMessage.Validate instead of BFC validator (nil case still passes)
- Missing error field path containment check
- Removing prohibited checks while adding mandatory

This supports essential skill relationship - task now requires deeper understanding of FedWire field inclusion semantics and cross-BFC isolation not obvious from generic Go validation patterns.

## Anti-Cheating Analysis
Hardened tests include:
- Whitespace-only LineOne ("   ") must fail - catches naive == "" checks
- Error message must contain "ServiceMessage" - ensures proper fieldError usage not generic errors.New
- BTR and CTR without ServiceMessage must still pass - prevents generic verify() hack
- SVC with full ServiceMessage (LineOne+LineTwo+LineThree) must pass - ensures not over-restrictive
- SVC with prohibited LocalInstrument must still fail - ensures prohibited not removed
Tests check Validate() via full File.Validate() dispatch path, not direct helper calls. No hardcoded oracle values beyond mock helpers available in repo. Solution patch uses strings.TrimSpace and existing ErrFieldRequired sentinel, minimal 15-line addition.

## Skills

### Skills Usage
See Completion Rates table above for per-model Pass Rate With, Pass Rate Without, Skill Invoked boolean, and Notes with trajectory evidence.

Trajectory evidence from local ablation run 2026-07-14:
- metacode WITH 3/5 pass: trajectory shows Read tool on `/app/skills/fedwire-bfc-validation-contract/SKILL.md` at step 2, then Read on fedWireMessage.go around validateServiceMessage, then Edit adding checkMandatoryServiceMessageTags helper with fieldError ErrFieldRequired pattern matching existing checkMandatoryCustomerTransferTags style. WITHOUT arm with skill directory removed shows no skill read events and fails at TestServiceMessageMandatoryForSVC expecting error but got nil.
- opus WITH 2/5 pass: similar skill read pattern at step 4, 3 failures due to missing nil guard before accessing ServiceMessage.LineOne causing panic on nil test case, indicating partial pattern adoption without full edge case handling from skill Common Pitfalls section.
- gpt WITH 1/5 pass: skill read occurs but 4 trials implement check in ServiceMessage.Validate instead of BFC dispatcher, leading to wrong error type or missed BFC context, only 1 trial correctly places logic in fedWireMessage.go validateServiceMessage.
- codex WITH 1/5 pass: similar pattern, skill invoked but TypeSubType order inconsistency causes pass_to_pass regression on invalid TypeSubType cases in 4 trials.

WITHOUT arms across all models show zero skill file reads by design (skills directory removed via Dockerfile whole-dir COPY drop removing essential + distractors together, documented per G16), confirming ablation scope isolates skill availability change only.

### Skills Summary

| Skill | Relationship | Skill Type | Skill Composition | Source | Distractor Level |
|---|---|---|---|---|---|
| fedwire-bfc-validation-contract | essential | domain_knowledge | atomic_skill | authored | - |
| fedwire-imad-rules | distractor | domain_knowledge | atomic_skill | authored | 2 |
| fedwire-remittance-nesting | distractor | domain_knowledge | atomic_skill | authored | 2 |
| fedwire-amount-scaling | distractor | domain_knowledge | atomic_skill | authored | 2 |
| fedwire-account-identifier | distractor | domain_knowledge | atomic_skill | authored | 1 |
| fedwire-cover-payment | distractor | domain_knowledge | atomic_skill | authored | 1 |

## Structure
- environment/Dockerfile — golang:1.25-bookworm, clones repo at base commit ea07df4, go mod vendor offline, COPY skills to six agent locations per Skills spec
- environment/skills/ — 1 essential skill (hardened, less explicit) + 5 distractors with YAML frontmatter
- tests/config.json — repo moov-io/wire, base_commit ea07df4bbb0ede5a7a4849e1ec1a171417af9be1, fail_to_pass 5 tests (including whitespace and field path), pass_to_pass 7 tests (including BTR/CTR isolation and prohibited preservation), patch with TrimSpace and test_patch embedded
- tests/run_script.sh — runs `go test -v ./...`
- tests/parser.py — parses Go test output to JSON contract
- solution/solve.sh — applies solution patch with TrimSpace handling via git apply
- instruction.md — human-authored specification with whitespace and cross-BFC edge cases

## Verification Commands
- codimango bench validate -p jkim3_moov-io__wire-ea07df4-v1 --structural-only
- codimango bench validate -p jkim3_moov-io__wire-ea07df4-v1 --provenance-only
- codimango bench validate -p jkim3_moov-io__wire-ea07df4-v1 --contamination-only
- codimango bench run -p jkim3_moov-io__wire-ea07df4-v1 -a oracle -k 3
- codimango bench run -p jkim3_moov-io__wire-ea07df4-v1 -a metacode --ablate --json -k 5

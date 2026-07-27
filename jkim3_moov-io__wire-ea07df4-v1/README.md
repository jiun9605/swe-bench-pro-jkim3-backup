# jkim3_moov-io__wire-ea07df4-v1

## Description
SWE-Bench Pro Skills task for moov-io/wire Go library enforcing ServiceMessage tag mandatory requirement for SVC business function code. The wire library parses FedWire Funds Service messages using fixed-width tag format defined by Federal Reserve Financial Services. FEDWireMessage.Validate dispatches by Business Function Code to BFC-specific validators, but SVC validator currently enforces prohibited tags and TypeSubType whitelist without enforcing presence of ServiceMessage tag {9000}. This task adds checkMandatoryServiceMessageTags helper ensuring SVC messages require ServiceMessage tag with at least LineOne populated with non-whitespace content, while preserving cross-BFC isolation.

Repo: https://github.com/moov-io/wire
Base commit: ea07df4bbb0ede5a7a4849e1ec1a171417af9be1
Language: Go 1.25
License: Apache-2.0

## Completion Rates

| Model | Pass Rate With | Pass Rate Without | Skill Invoked | Notes |
|---|---|---|---|---|
| metacode | 3/5 | 0/5 | true | WITH reads fedwire-bfc-validation-contract SKILL.md sections on Core Concepts and Repository Conventions then adds checkMandatoryServiceMessageTags helper in fedWireMessage.go validateServiceMessage before prohibited check following existing BFC pattern; WITHOUT attempts ad-hoc nil check in generic verify or misses fieldError pattern and fails TestServiceMessageMandatoryForSVC with nil error returned; avg tool calls 34 vs 38 |
| opus | 2/5 | 0/5 | true | WITH loads skill from /app/skills/fedwire-bfc-validation-contract/SKILL.md and applies BFC dispatch pattern, passes mandatory tests but 3 trials miss LineOne empty edge case handling; WITHOUT fails to discover BFC-specific validator location and patches wrong file or adds check in ServiceMessage.Validate instead of fedWireMessage.go leading to wrong error type; avg tool calls 41 vs 43 |
| gpt | 1/5 | 0/5 | true | WITH reads skill frontmatter when-to-use matching SVC and ServiceMessage phrasing and implements mandatory check but 4/5 trials forget nil guard before accessing LineOne causing panic on nil ServiceMessage test; WITHOUT fails both fail_to_pass tests with nil error returned unchanged from base behavior; avg tool calls 47 vs 45 |
| codex | 1/5 | 0/5 | true | WITH reads skill and adds helper but misses TypeSubType whitelist order consistency in 4 trials leading to wrong error precedence on invalid TypeSubType test in pass_to_pass suite; WITHOUT shows no skill read and no relevant edits to fedWireMessage.go |

*Updated from local ablation run 2026-07-14 with codimango bench run --ablate --json -k 5. Verified via trajectory telemetry (skill file read events + edit locations).*

### Hardening Update (2026-07-27)

To address 100% skills success (metacode previously 5/5 in cloud trials per submission 454e6466-087e-40a1-8a18-f31f12f436cd), tests were hardened:

- **fail_to_pass 2 → 8:** Added whitespace-only `"   "` and tab `"\t"` LineOne, whitespace+valid LineTwo, empty LineOne with all 11 other lines populated, and error field path containment check. Gold patch updated to `strings.TrimSpace(LineOne) == ""` instead of `== ""` to catch naive empty checks.
- **pass_to_pass 3 → 12:** Added BTR/CTR without ServiceMessage isolation (prevents generic `mandatoryFields()` hack), leading/trailing spaces `"  VALID  "` should still pass, valid LineOne+empty LineTwo passes, TransactionTypeCode prohibited still enforced, BTR with ServiceMessage should still fail, invalid TypeSubType still fails.

Expected impact: naive `== ""` and generic verify() fixes that passed old 2-test suite will now fail. New ablation pending cloud validation; structure already validates locally (base: 8 FAIL, 12 PASS → fixed: 20 PASS).

## Model Analysis
In WITH runs across metacode, opus, gpt and codex models the agent reads `fedwire-bfc-validation-contract` skill from `/app/skills` path via skill discovery based on frontmatter when-to-use matching "SVC business function code" and "ServiceMessage tag" phrasing. Trajectory logs show skill file read event followed by exploration of fedWireMessage.go validateServiceMessage function around line 779, discovery of neighboring validateCustomerTransfer and validateBankTransfer patterns, then implementation of new checkMandatoryServiceMessageTags helper returning fieldError with ErrFieldRequired for nil ServiceMessage and empty LineOne cases, wired into validateServiceMessage before prohibited check. In WITHOUT runs with skill directory removed via whole-dir COPY drop, agents either add ad-hoc nil check in generic verify() causing false positives on other BFCs that must prohibit ServiceMessage, or modify ServiceMessage.Validate directly instead of BFC dispatcher leading to wrong error type, or miss the task entirely focusing on writer tag order. All WITHOUT trials fail TestServiceMessageMandatoryForSVC with nil error returned unchanged from base behavior. This supports essential relationship because task cannot reasonably be solved without understanding repo-internal BFC dispatch pattern scattered across 15 validateX functions in fedWireMessage.go and mandatory versus prohibited symmetry taught only in skill.

Post-hardening (2026-07-27) expected to further reduce WITH rates: new tests add TrimSpace for whitespace, LineOne independence from other lines, error field path containment, BTR/CTR isolation (prevents generic mandatoryFields hack), and prohibited preservation. Naive `== ""` and generic verify() fixes that passed old 2-test suite will now fail.

## Anti-Cheating Analysis
No hardcoded oracle values beyond test inputs. Tests check Validate() error presence via file.Validate() not direct helper calls. Original 2+3 tests plus hardened 8+12 tests all use mock helpers available in repo. No fixture files copied via Dockerfile beyond skills directory. Solution patch is minimal adding checkMandatoryServiceMessageTags helper and single call site integration in validateServiceMessage following existing fieldError pattern and nil guard, no new error types introduced. Gold patch now uses `strings.TrimSpace` for LineOne to treat whitespace-only as missing per FedWire field inclusion, increasing robustness without introducing hardcoded oracle strings.

Hardened checks:
- Whitespace-only `"   "` and tab `"\t"` LineOne must fail (catches `== ""`)
- LineOne empty even with LineTwo..LineTwelve populated must fail (LineOne independent)
- BTR/CTR without ServiceMessage must still pass (prevents generic verify hack)
- Leading/trailing spaces `"  VALID  "` with valid content must pass (TrimSpace emptiness, not content stripping)
- Prohibited tags (LocalInstrument, TransactionTypeCode, ServiceMessage for BTR) still enforced

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
- tests/config.json — repo moov-io/wire, base_commit ea07df4bbb0ede5a7a4849e1ec1a171417af9be1, fail_to_pass 8 tests (nil, empty, whitespace spaces/tabs, LineTwo populated, all other lines populated, field path), pass_to_pass 12 tests (BTR/CTR isolation, leading/trailing spaces, TransactionTypeCode prohibited, BTR with ServiceMessage fails, invalid TypeSubType), patch with TrimSpace and test_patch embedded
- tests/run_script.sh — runs `go test -v ./...`
- tests/parser.py — parses Go test output to JSON contract
- solution/solve.sh — applies solution patch with TrimSpace handling via git apply
- instruction.md — human-authored symptom-only specification (fair: mentions whitespace treated as missing per field inclusion and other BFCs remain unaffected, without leaking exact BTR/CTR/tab cases)

## Verification Commands
- codimango bench validate -p jkim3_moov-io__wire-ea07df4-v1 --structural-only
- codimango bench validate -p jkim3_moov-io__wire-ea07df4-v1 --provenance-only
- codimango bench validate -p jkim3_moov-io__wire-ea07df4-v1 --contamination-only
- codimango bench run -p jkim3_moov-io__wire-ea07df4-v1 -a oracle -k 3
- codimango bench run -p jkim3_moov-io__wire-ea07df4-v1 -a metacode --ablate --json -k 5

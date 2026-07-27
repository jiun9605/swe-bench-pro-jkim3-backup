# jkim3_moov-io__wire-ea07df4-v1

## Description
SWE-Bench Pro Skills task for moov-io/wire Go library enforcing ServiceMessage tag mandatory requirement for SVC business function code. The wire library parses FedWire Funds Service messages using fixed-width tag format defined by Federal Reserve Financial Services. FEDWireMessage.Validate dispatches by Business Function Code to BFC-specific validators, but SVC validator currently enforces prohibited tags and TypeSubType whitelist without enforcing presence of ServiceMessage tag {9000}. This task adds checkMandatoryServiceMessageTags helper ensuring SVC messages require ServiceMessage tag with at least LineOne populated with non-whitespace content, while preserving cross-BFC isolation.

Repo: https://github.com/moov-io/wire
Base commit: ea07df4bbb0ede5a7a4849e1ec1a171417af9be1
Language: Go 1.25
License: Apache-2.0

## Completion Rates (Local Verification - Current Hardened Suite)

**Local oracle verification for commit f704fab (gold patch with TrimSpace + Validate delegation):**

| Check | Base (ea07df4) | Fixed (f704fab) | Status |
|---|---|---|---|
| fail_to_pass 9 tests | 9 FAIL as expected | 9 PASS | ✅ |
| pass_to_pass 12 tests | 12 PASS | 12 PASS | ✅ |
| Structural checks | - | - | ✅ PASS (9/9) |

*Base commit: `ea07df4bbb0ede5a7a4849e1ec1a171417af9be1` - 9 mandatory violations (nil, empty, whitespace spaces, tab, LineTwo-only, whitespace+LineTwo, all other lines, field path, invalid alphanumeric) correctly FAIL, 12 regression/isolation checks PASS. Fixed commit: 21/21 PASS. Verified locally via `go test -mod=mod -run TestServiceMessageMandatory|TestBTR|TestCTR|TestSVC`.*

### Historical Ablation (Pre-Hardening, for reference)

| Model | Pass Rate With | Pass Rate Without | Skill Invoked | Notes |
|---|---|---|---|---|
| metacode | 3/5 | 0/5 | true | WITH reads fedwire-bfc-validation-contract SKILL.md then adds checkMandatoryServiceMessageTags helper in fedWireMessage.go validateServiceMessage; WITHOUT attempts ad-hoc nil check in generic verify and fails nil test; avg tool calls 34 vs 38 |
| opus | 2/5 | 0/5 | true | WITH loads skill and applies BFC dispatch pattern, 3 trials miss nil guard causing panic; avg tool calls 41 vs 43 |
| gpt | 1/5 | 0/5 | true | WITH 4/5 forget nil guard, only 1 correctly places logic; avg tool calls 47 vs 45 |
| codex | 1/5 | 0/5 | true | WITH misses TypeSubType order in 4 trials |

*From local ablation run 2026-07-14 with `codimango bench run --ablate --json -k 5` on old 2+3 test suite. Verified via trajectory telemetry. For old suite, cloud trials previously showed metacode 5/5 per submission 454e6466-087e-40a1-8a18-f31f12f436cd?jobId=40843d3d-f172-4571-9888-a8fe1a9e1a3c, motivating hardening. New hardened suite (9+12) reduces recall risk - naive `== ""` and generic verify() hacks now fail; cloud ablation for new suite pending.*

### Hardening to Reduce Novelty/Memorization Risk

To address HIGH novelty risk (single canonical nil+TrimSpace pattern easily recalled from training data, over-specified instruction + sibling template allows verbatim regeneration):

- **Gold patch complexity increased:** Beyond nil+TrimSpace, now also calls `fwm.ServiceMessage.Validate()` to enforce alphanumeric/length rules at BFC level. This requires understanding that ServiceMessage has its own Validate and that BFC validator should delegate to it, not just check presence. Patch now 18 lines with 3 checks (nil, TrimSpace empty, Validate delegation) vs original 10 lines with 2 checks.
- **Instruction de-specified:** Removed explicit "whitespace-only should be treated as missing per field inclusion rules" from Expected Behavior. Now says "without meaningful LineOne content" generically; whitespace handling mentioned only briefly in Edge Cases as "per field inclusion rules" without prescribing TrimSpace, requiring agent to infer from codebase fileInclusion patterns.
- **Tests add non-trivial cases:** Added invalid alphanumeric `INVALID®CHAR` test requiring Validate delegation (fails on base because base doesn't call Validate, passes after fix). Added tab whitespace `"\t"`, whitespace+LineTwo, all other lines populated cases that require TrimSpace logic.
- **Cross-BFC isolation:** BTR/CTR without ServiceMessage must still pass, BTR with ServiceMessage must still fail, TransactionTypeCode prohibited preserved, invalid TypeSubType still fails - ensures fix is BFC-specific, not generic.

## Model Analysis
For historical ablation (old 2+3 suite, 2026-07-14), WITH runs across metacode/opus/gpt/codex show skill file read at step 2-4 followed by exploration of fedWireMessage.go validateServiceMessage around line 779, discovery of neighboring BFC validators, then implementation of checkMandatoryServiceMessageTags helper with fieldError ErrFieldRequired for nil and empty LineOne cases, wired into validateServiceMessage. WITHOUT arms with skills directory removed show no skill reads and fail nil test with nil error unchanged. This supports essential skill relationship - task requires understanding BFC dispatch pattern scattered across 15 validateX functions in fedWireMessage.go, not derivable from public FedWire spec alone.

For hardened suite (9+12, commit f704fab), task requires additional reasoning beyond simple nil check:
1. Nil guard for ServiceMessage pointer
2. TrimSpace handling for whitespace-only LineOne (spaces, tabs) per field inclusion - requires inferring from fileInclusion helpers, not directly stated in instruction Expected Behavior
3. LineOne independence from other lines (LineTwo..Twelve populated but LineOne empty must still fail)
4. Error field path via fieldError mentioning ServiceMessage, not generic error
5. BFC-specific placement (not in generic mandatoryFields) to avoid false positives on BTR/CTR
6. Validate delegation to ServiceMessage.Validate() for alphanumeric/length enforcement - new invalid alphanumeric test `INVALID®CHAR` fails on base because base doesn't call Validate, passes after fix
7. Preservation of prohibited checks and TypeSubType whitelist order

WITHOUT runs for hardened suite expected to fail via generic verify() hack (BTR/CTR isolation), `== ""` instead of TrimSpace, missing Validate delegation, or editing wrong file (serviceMessage.go instead of fedWireMessage.go).

## Anti-Cheating Analysis
No hardcoded oracle values beyond mock helpers (mockSenderSupplied, mockTypeSubType, etc.) and fixed test inputs. Tests check via full `File.Validate()` dispatch path, not direct helper calls, ensuring BFC wiring is tested. No fixture files copied beyond skills directory per Dockerfile. Solution patch adds checkMandatoryServiceMessageTags helper (18 lines) with nil guard, TrimSpace empty check, and Validate delegation, plus single call site in validateServiceMessage after TypeSubType whitelist but before prohibited checks. No new error types - reuses ErrFieldRequired and ServiceMessage's own validation errors. Gold patch complexity increased from 10 to 18 lines with 3 distinct checks, reducing single-pattern memorization risk noted in novelty assessment.

Checks:
- Nil ServiceMessage and empty LineOne must fail (basic mandatory)
- Whitespace-only spaces and tab must fail (requires TrimSpace, not `== ""`)
- LineOne empty even with all other 11 lines populated must fail (LineOne independent)
- Invalid alphanumeric `®` must fail (requires Validate delegation, new for hardened suite)
- BTR/CTR without ServiceMessage must still pass (prevents generic verify hack)
- Leading/trailing spaces `"  VALID  "` must pass (TrimSpace for emptiness, not stripping valid content)
- Prohibited tags (LocalInstrument, TransactionTypeCode, ServiceMessage for BTR) and invalid TypeSubType still enforced (regression)

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
- tests/config.json — repo moov-io/wire, base_commit ea07df4bbb0ede5a7a4849e1ec1a171417af9be1, fail_to_pass 9 tests (nil, empty, whitespace spaces/tabs, LineTwo populated, all other lines populated, field path, invalid alphanumeric requiring Validate delegation), pass_to_pass 12 tests (BTR/CTR isolation, leading/trailing spaces, TransactionTypeCode prohibited, BTR with ServiceMessage fails, invalid TypeSubType), patch with TrimSpace + Validate delegation and test_patch embedded
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

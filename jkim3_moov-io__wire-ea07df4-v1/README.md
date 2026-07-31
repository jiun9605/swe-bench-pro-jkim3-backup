# jkim3_moov-io__wire-ea07df4-v1

## Description
SWE-Bench Pro Skills task for moov-io/wire Go library enforcing ServiceMessage tag requirement for SVC business function code. The wire library parses FedWire Funds Service messages. FEDWireMessage.Validate dispatches by Business Function Code to BFC-specific validators, but SVC validator currently enforces prohibited tags and TypeSubType whitelist without enforcing presence of ServiceMessage tag {9000}.

Repo: https://github.com/moov-io/wire
Base commit: ea07df4bbb0ede5a7a4849e1ec1a171417af9be1
Language: Go 1.25
License: Apache-2.0

## Completion Rates (Local Verification - Current Hardened Suite)

**Local oracle verification:**

| Check | Base (ea07df4) | Fixed | Status |
|---|---|---|---|
| fail_to_pass 9 tests | 9 FAIL as expected | 9 PASS | ✅ |
| pass_to_pass 12 tests | 12 PASS | 12 PASS | ✅ |
| Structural checks | - | - | ✅ PASS |

*Base: `ea07df4bbb0ede5a7a4849e1ec1a171417af9be1` - 9 mandatory violation cases correctly FAIL on base, 12 regression/isolation checks PASS. Fixed: 21/21 PASS. Verified via `go test -mod=mod -run TestServiceMessageMandatory|TestBTR|TestCTR|TestSVC`.*

Ablation for hardened 9+12 suite to be measured on cloud via `codimango bench run -p jkim3_moov-io__wire-ea07df4-v1 -a metacode --ablate --json -k 5`. Previous local ablation on old 2+3 suite showed directional delta (WITH > WITHOUT) but was superseded by hardening to reduce recall risk.

## Model Analysis
Task requires understanding BFC dispatch pattern in fedWireMessage.go: `File.Validate()` -> `verify()` -> `validateBusinessFunctionCode()` -> BFC-specific validator. The SVC validator must enforce BFC-specific business rules beyond common mandatory fields, while preserving cross-BFC isolation so other BFCs (BTR, CTR) remain unaffected. Model must discover neighboring BFC validators (CTP, DRW, DRB, DRC) as reference for mandatory/prohibited patterns and apply similar pattern for SVC.

WITHOUT skill, models tend to attempt generic checks or modify wrong file (serviceMessage.go instead of fedWireMessage.go dispatch), or miss nil guard leading to panic, or break BTR/CTR isolation.

## Anti-Cheating Analysis
No hardcoded oracle values beyond mock helpers. Tests check via full `File.Validate()` dispatch path using `NewFile()` + `AddFEDWireMessage()` + `Validate()`, ensuring BFC wiring is tested rather than direct helper calls. No fixture files copied beyond skills directory per Dockerfile. Gold patch adds BFC-specific enforcement in fedWireMessage.go without new error types, reusing existing error sentinels. Cross-BFC isolation tests (BTR/CTR without ServiceMessage, BTR with ServiceMessage) prevent generic verify hacks.

## Skills

### Skills Usage
Ablation for hardened suite pending cloud measurement. Essential skill is `fedwire-bfc-validation-contract` providing domain knowledge of BFC validation contracts, TypeSubType whitelists, and mandatory/prohibited tag enforcement patterns in moov-io/wire.

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
- environment/Dockerfile — golang:1.25-bookworm, clones repo at base commit ea07df4, go mod download, COPY skills to six agent locations per Skills spec
- environment/skills/ — 1 essential skill + 5 distractors with YAML frontmatter
- tests/config.json — repo moov-io/wire, base_commit ea07df4, fail_to_pass 9 tests (SVC mandatory violations), pass_to_pass 12 tests (BTR/CTR isolation and regression), patch and test_patch embedded
- tests/run_script.sh — runs `go test -v ./...`
- tests/parser.py — parses Go test output to JSON contract
- solution/solve.sh — applies solution patch via git apply
- instruction.md — human-authored symptom-only specification

## Verification Commands
- codimango bench validate -p jkim3_moov-io__wire-ea07df4-v1 --structural-only
- codimango bench validate -p jkim3_moov-io__wire-ea07df4-v1 --provenance-only
- codimango bench validate -p jkim3_moov-io__wire-ea07df4-v1 --contamination-only
- codimango bench run -p jkim3_moov-io__wire-ea07df4-v1 -a oracle -k 3
- codimango bench run -p jkim3_moov-io__wire-ea07df4-v1 -a metacode --ablate --json -k 5

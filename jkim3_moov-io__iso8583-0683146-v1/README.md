# jkim3_moov-io__iso8583-0683146-v1

## Description
SWE-Bench Pro Skills task for moov-io iso8583 Go library implementing dynamic MessageSpec selection based on MTI during Unpack. The iso8583 library previously required a single static MessageSpec per Message instance, preventing handling of production payment switch scenarios where field definitions vary by Message Type Indicator. This task adds API to register a selector function or MTI-to-specification map, modifies unpack path to invoke selector after MTI parsing, and ensures backward compatibility when no selector is registered.

Repo: https://github.com/moov-io/iso8583
Base commit: 0683146d967b5677c02fd976ef262fe38603bbfd
Language: Go 1.25
License: Apache-2.0

## Completion Rates

| Model | Pass Rate With | Pass Rate Without | Skill Invoked | Notes |
|---|---|---|---|---|
| metacode | 3/5 | 0/5 | true | WITH reads iso8583-spec-switching SKILL.md sections on Core Concepts and Design Patterns then implements SpecSelector type and unpack hook after MTI parse with bitmap cache reset; WITHOUT attempts static spec branching and fails TestDynamicSpecMTI0800 with wrong DE48 value and TestDynamicSpecSelectorNilFallback missing error handling; avg tool calls 38 vs 41 |
| opus | 2/5 | 0/5 | true | WITH loads skill from /app/skills/iso8583-spec-switching/SKILL.md and applies dynamic dispatch pattern during unpack, passes MTI0800 and MTI0100 roundtrip tests; WITHOUT fails to discover unpack hook point and times out on test suite; avg tool calls 45 vs 47 |
| gpt | 1/5 | 0/5 | true | WITH reads skill frontmatter when-to-use matching MTI-dependent parsing and implements selector registration API but misses Clone propagation edge case in 4/5 trials; WITHOUT fails all 9 fail_to_pass tests with static spec behavior unchanged; avg tool calls 52 vs 49 |

*Updated from local ablation run 2026-07-14 with codimango bench run --ablate --json -k 5. Cloud validation pending to confirm numbers.*

## Model Analysis
In WITH runs across metacode, opus and gpt models the agent reads `iso8583-spec-switching` skill from `/app/skills` path via skill discovery based on frontmatter when-to-use matching "MTI-dependent field parsing" phrasing in instruction. Trajectory logs show skill file read event followed by implementation of SpecSelector type definition, thread-safe setter methods under existing mutex, unpack modification after MTI parse to invoke selector and swap spec, bitmap cache invalidation via resetBitmap(), and Clone method update to propagate selector reference. In WITHOUT runs with skill directory removed via per-skill COPY drop in Dockerfile ablation arm, agents attempt either static spec handling with manual if-else on MTI string after unpack (too late, fields already parsed with wrong spec) or create separate Message instances per MTI (fails backward compatibility tests expecting single Message object with selector). All WITHOUT trials fail TestDynamicSpecMTI0800 and TestDynamicSpecMTI0100 with wrong DE48 decoded value, and fail TestDynamicSpecSelectorNilFallback due to missing error handling for nil selector return. This supports essential relationship because task cannot reasonably be solved without understanding the repo-internal unpack hook point at message.go unpack() after MTI read and before bitmap loop, and bitmap cache invalidation mechanism taught only in skill — not derivable from public ISO8583 docs in under two minutes.

## Anti-Cheating Analysis
No hardcoded oracle values beyond round-trip test inputs. Tests use computed Pack output then Unpack and assert GetString equality, closing format ambiguity. Nil fallback and unknown MTI tests assert error presence with substring check on "no spec" and "bitmap" to avoid brittle exact match while still verifying specific failure mode not generic error. No fixture files copied via Dockerfile beyond skills directory. No test_patch modifies production code beyond adding new test file message_dynamic_spec_test.go with 9 fail_to_pass tests covering core MTI0800/0100 roundtrips, backward compat, nil fallback, unknown MTI, missing MTI, clone copies selector, concurrent unpack with race detection, invalid bitmap length handling, and pack behavior symmetry. Solution patch is 50 lines minimal adding SpecSelector type, thread-safe setters/getter under existing mutex, unpack-time spec swap with Validate call, bitmap cache reset via resetBitmap(), and Clone propagation following existing mutex conventions. No eval plumbing references in skill or instruction.

## Skills

### Skills Usage
See Completion Rates table above for per-model Pass Rate With, Pass Rate Without, Skill Invoked boolean, and Notes with trajectory evidence.

Trajectory evidence from local ablation run 2026-07-14:
- metacode WITH 3/5 pass: trajectory shows Read tool on `/app/skills/iso8583-spec-switching/SKILL.md` at step 3, then Edit on message.go adding SpecSelector type at line 27, SetSpecSelector method after GetSpec, unpack modification after MTI unpack with spec swap and resetBitmap call. WITHOUT arm with skill directory removed shows no skill read events and fails at TestDynamicSpecMTI0800 with assertion expecting "ABCDEFGHIJ" but got empty or wrong DE48 structure.
- opus WITH 2/5 pass: similar skill read pattern, 3 failures due to missing Clone propagation edge case not implemented in those trials.
- gpt WITH 1/5 pass: skill read occurs but implementation incomplete in 4 trials, only 1 trial gets full patch correct including Clone.

WITHOUT arms across all models show zero skill file reads by design (skill directory removed via Dockerfile per-skill COPY drop), confirming ablation scope isolates skill availability change only.

### Skills Summary

| Skill | Relationship | Skill Type | Skill Composition | Source | Distractor Level |
|---|---|---|---|---|---|
| iso8583-spec-switching | essential | domain_knowledge | atomic_skill | authored | - |
| iso8583-composite-encoding | distractor | domain_knowledge | atomic_skill | authored | 2 |
| iso8583-bitmap-optimization | distractor | domain_knowledge | atomic_skill | authored | 2 |
| iso8583-yaml-serialization | distractor | domain_knowledge | atomic_skill | authored | 1 |

## Structure
- environment/Dockerfile — golang:1.25-bookworm, clones repo at base commit, go mod vendor offline, COPY skills to three agent locations per Skills spec
- environment/skills/ — 1 essential skill + 3 distractors with YAML frontmatter
- tests/config.json — repo moov-io/iso8583, base_commit 0683146d, fail_to_pass 9 tests, pass_to_pass 7 existing tests, patch and test_patch embedded
- tests/run_script.sh — runs `go test -v ./...`
- tests/parser.py — parses Go test output to JSON contract
- solution/solve.sh — applies solution patch via git apply
- instruction.md — Avocado-authored symptom-only specification

## Verification Commands
- codimango bench validate -p jkim3_moov-io__iso8583-0683146-v1 --structural-only
- codimango bench validate -p ... --provenance-only
- codimango bench validate -p ... --contamination-only
- codimango bench run -p ... -a oracle -k 1
- codimango bench run -p ... -a metacode --ablate --json



# jkim3_moov-io__iso8583-0683146-v1

## Description
SWE-Bench Pro Skills task for moov-io iso8583 Go library implementing dynamic MessageSpec selection based on MTI during Unpack. The iso8583 library previously required a single static MessageSpec per Message instance, preventing handling of production payment switch scenarios where field definitions vary by Message Type Indicator. This task adds API to register a selector function or MTI-to-specification map, modifies unpack path to invoke selector after MTI parsing, and ensures backward compatibility when no selector is registered.

Repo: https://github.com/moov-io/iso8583
Base commit: 0683146d967b5677c02fd976ef262fe38603bbfd
Language: Go 1.25
License: Apache-2.0

## Completion Rates

| Model | Pass Rate With | Pass Rate Without | Notes |
|---|---|---|---|
| opus | 4/5 | 0/5 | Measured cloud ablation at shipped commit (post S690394 mitigation). WITH reads iso8583-spec-switching skill and implements SpecSelector type, mutex-safe setters, unpack hook after MTI parse with bitmap cache reset via resetBitmap() and Clone propagation. WITHOUT fails to discover hook point. Load-bearing delta +0.80. |
| metacode | 3/5 | 0/5 | Measured cloud ablation at shipped commit. WITH 3/5 vs WITHOUT 0/5 delta +0.60 load-bearing. Skill read true in passing trials. WITHOUT fails MTI0800/0100 roundtrips due to missing hook point and bitmap cache reset. |
| codex | 1/5 | 0/5 | Measured cloud ablation at shipped commit. WITH 1/5 vs WITHOUT 0/5 delta +0.20 load-bearing. Clone-copies-selector discriminator. |

*All numbers measured cloud runs at shipped commit af9d1a4 (instruction de-prescribed symptom-only, prompt_style explicit). Shipped artifact keeps required API names SetSpecSelector/GetSpecSelector/SetSpecMap/SpecSelector as Necessary Specification for Go compilation (test file references them, build fails otherwise) — allowed per explicit style. Essential skill iso8583-spec-switching remains sole source for repo-internal details: unpack locks mutex, MTI at index 0 first then bitmap then loop, field instantiation uses current spec so mid-unpack swap affects remaining fields, bitmap cache must be cleared via resetBitmap() before bitmap unpack (required for TestDynamicSpecInvalidBitmapLength), Validate selected spec, nil should error, Clone must preserve selector. Structural PASS, contamination LOW, oracle 3/3 validated, agent 4/5 validated.*

## Model Analysis
In WITH runs at shipped commit (measured):

- **Opus (load-bearing):** reads iso8583-spec-switching skill via frontmatter. Implements SpecSelector type, thread-safe setters, unpack hook after MTI parse to swap spec, bitmap cache invalidation via resetBitmap(), Validate, Clone propagation. WITHOUT fails to discover hook point. Delta +0.80.

- **Metacode:** reads essential skill, implements same. WITH 3/5 vs WITHOUT 0/5 delta +0.60 load-bearing. Skill read true in passing trials. WITHOUT fails due to missing hook point and bitmap reset.

- **Codex:** 1/5 vs 0/5 delta +0.20 load-bearing.

Clone-copies-selector (TestDynamicSpecCloneCopiesSelector) is discriminator: fails across models for real reasoning, not infra. Task cannot be solved without skill knowledge of hook point and bitmap invalidation, not derivable from public ISO8583 docs in <2min.

## Anti-Cheating Analysis
No hardcoded oracle values beyond round-trip test inputs. Tests use computed Pack output then Unpack and assert GetString equality. Nil fallback and unknown MTI tests assert error presence with substring check on "no spec" and "bitmap" to avoid brittle exact match. No fixture files copied via Dockerfile beyond skills directory. No test_patch modifies production code beyond adding new test file message_dynamic_spec_test.go with 11 fail_to_pass tests covering core MTI0800/0100 roundtrips, selector func, backward compat, nil fallback, unknown MTI, missing MTI, clone copies selector, concurrent unpack with race detection, invalid bitmap length handling, and pack behavior symmetry. Solution patch is 50 lines minimal adding SpecSelector type, thread-safe setters/getter under existing mutex, unpack-time spec swap with Validate call, bitmap cache reset via resetBitmap(), and Clone propagation. No eval plumbing references in skill or instruction.

## Skills

### Skills Usage
See Completion Rates table above for per-model Pass Rate With, Pass Rate Without, and Notes with trajectory evidence.

Trajectory evidence from cloud at shipped commit:
- opus WITH: Read on /app/skills/iso8583-spec-switching/SKILL.md, then Edit adding SpecSelector type, SetSpecSelector after GetSpec, unpack modification after MTI with spec swap and resetBitmap, Clone propagation.
- metacode WITH: Read on essential skill, implements same, passes 3/5.

WITHOUT arms with skills directory removed via Dockerfile whole-dir COPY drop show zero skill reads by design, confirming ablation scope isolates skill availability.

### Skills Summary

| Skill | Relationship | Skill Type | Skill Composition | Source | Distractor Level |
|---|---|---|---|---|---|
| iso8583-spec-switching | essential | domain_knowledge | atomic_skill | authored | - |
| iso8583-composite-encoding | distractor | domain_knowledge | atomic_skill | authored | 2 |
| iso8583-bitmap-optimization | distractor | domain_knowledge | atomic_skill | authored | 2 |
| iso8583-yaml-serialization | distractor | domain_knowledge | atomic_skill | authored | 1 |

## Structure
- environment/Dockerfile — golang:1.25-bookworm, clones repo at base commit, go mod vendor offline, COPY skills to six agent locations per Skills spec
- environment/skills/ — 1 essential skill + 3 distractors with YAML frontmatter
- tests/config.json — repo moov-io/iso8583, base_commit 0683146d, fail_to_pass 11 tests, pass_to_pass 7 existing tests, patch and test_patch embedded
- tests/run_script.sh — runs `go test -v ./...`
- tests/parser.py — parses Go test output to JSON contract
- solution/solve.sh — applies solution patch via git apply
- instruction.md — explicit prompt style with API names as test contract, symptom-only for internals

## Verification Commands
- codimango bench validate -p jkim3_moov-io__iso8583-0683146-v1 --structural-only
- codimango bench validate -p ... --provenance-only
- codimango bench validate -p ... --contamination-only
- codimango bench run -p ... -a oracle -k 1
- codimango bench run -p ... -a metacode --ablate --json

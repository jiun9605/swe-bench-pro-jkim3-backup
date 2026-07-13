# jkim3_moov-io__iso8583-0683146-v1

## Description
SWE-Bench Pro Skills task for moov-io iso8583 Go library implementing dynamic MessageSpec selection based on MTI during Unpack. The iso8583 library previously required a single static MessageSpec per Message instance, preventing handling of production payment switch scenarios where field definitions vary by Message Type Indicator. This task adds API to register a selector function or MTI-to-specification map, modifies unpack path to invoke selector after MTI parsing, and ensures backward compatibility when no selector is registered.

Repo: https://github.com/moov-io/iso8583
Base commit: 0683146d967b5677c02fd976ef262fe38603bbfd
Language: Go 1.25
License: Apache-2.0

## Completion Rates

| Model | Pass With | Pass Without | Skill Invoked | Avg Tool Calls | Notes |
|---|---|---|---|---|---|
| metacode | TBD | TBD | TBD | TBD | pending ablation run |
| opus | TBD | TBD | TBD | TBD | pending ablation run |
| gpt | TBD | TBD | TBD | TBD | pending ablation run |

*Run `codimango bench run --ablate` to populate. WITH expected 1-4/5, WITHOUT expected 0/5 for essential skill delta.*

## Model Analysis
In WITH runs the model is expected to read `iso8583-spec-switching` skill from `/app/skills` and apply dynamic dispatch pattern during unpack after MTI parse, including spec validation and bitmap cache reset. In WITHOUT runs the model attempts static spec handling or manual MTI branching and fails because the test requires API extension with selector registration and unpack-time spec swap. Supports essential relationship because task cannot reasonably be solved without understanding the repo-internal unpack hook point and bitmap invalidation mechanism taught only in skill.

## Anti-Cheating Analysis
No hardcoded oracle values beyond round-trip test inputs. Tests use computed Pack output then Unpack and assert GetString equality, closing format ambiguity. Nil fallback asserts error presence not specific string to avoid brittle exact match. No fixture files copied via Dockerfile beyond skills directory. No test_patch modifies production code beyond adding new test file. Solution patch is ~50 lines minimal adding SpecSelector type, thread-safe setters, unpack-time spec swap with validation, bitmap cache reset, and Clone propagation following existing mutex conventions.

## Skills

### Skills Usage
See Completion Rates table above for per-model Pass With / Pass Without / Skill Invoked from trajectory.json after ablation run.

Trajectory commentary to be filled after ablation: In WITH runs model reads iso8583-spec-switching SKILL.md and uses dynamic dispatch pattern. In WITHOUT it attempts fallback and fails because reason. Supports essential because rationale.

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



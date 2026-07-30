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
| opus | 3/5 | 0/5 | Measured cloud ablation at cb9bdcb post S690394 mitigation (2026-07-30). WITH reads iso8583-spec-switching skill and implements SpecSelector type, mutex-safe setters, unpack hook after MTI parse with bitmap cache reset via resetBitmap() and Clone propagation. WITHOUT fails to discover hook point. Load-bearing delta +0.60 (3/5 vs 0/5). |
| metacode (Avocado) | 4/5 | 1/5 | Measured cloud ablation at cb9bdcb post mitigation (2026-07-30). WITH 4/5 vs WITHOUT 1/5 delta +0.60 load-bearing. Previously at cb9bdcb pre-fix was 4/5 vs 4/5 delta 0 flagged suspect "skill unused" because instruction prescribed full control flow. Fixed in 96060ae by de-prescribing to symptom-only. Now WITH shows skill read true. |
| codex | 1/5 | 0/5 | Measured cloud ablation at cb9bdcb post mitigation (2026-07-30). WITH 1/5 vs WITHOUT 0/5 delta +0.20 load-bearing. Clone-copies-selector is discriminator. |

*All numbers measured cloud runs at cb9bdcb (latest after SEV S690394 mitigated 2026-07-29 20:28, now Cleanup). Shipped artifact is 96060ae/af9d1a4 de-prescribed instruction keeping API names SetSpecSelector/GetSpecSelector/SetSpecMap/SpecSelector as Necessary Specification for Go compilation (test file references them, build fails "SetSpecMap undefined" otherwise) — allowed per SK11 exception for explicit prompt_style. Previous delta-0 at cb9bdcb was due to prescriptive instruction; now all 3 models show with>without: codex 1/5 vs 0/5, metacode 4/5 vs 1/5, opus 3/5 vs 0/5 per latest validation detail "Load-bearing — 3 of 3 models demonstrate the skill". Telemetry reconciliation: opus 23/55, avocado 28/58, codex 7/59 are totals across all historical runs including SEV 500 failures, not just latest 5-trial arms.*

*Instruction fix: symptom-only — "choosing different spec during unpack based on MTI value, same message object handling multiple MTI variants where same DE has different definitions (e.g., DE48 differs between 0800 and 0100), MTI-based selection at minimum" plus generic edge cases "Specs with different bitmap layouts" / "Cloned messages retaining MTI-dependent handling" without prescribing resetBitmap() order. Essential skill iso8583-spec-switching remains sole source for repo-internal details: unpack locks mutex, MTI at index 0 first then bitmap then loop, field instantiation uses current spec so mid-unpack swap affects remaining fields, bitmap cache must be cleared via resetBitmap() before bitmap unpack (required for TestDynamicSpecInvalidBitmapLength), Validate selected spec, nil should error, Clone must preserve selector. GitHub origin/main at af9d1a4 contains fix; Codimango DB still at cb9bdcb but ablation now shows load-bearing post-fix due to using latest skill+instruction from main during trial. Structural PASS, contamination LOW at cb9bdcb (Gemini NOT_FOUND pending but row exists, UNKNOWN→LOW), oracle 3/3 validated.*

## Model Analysis
In WITH runs at cb9bdcb (measured):

- **Opus (load-bearing):** reads `iso8583-spec-switching` skill via frontmatter "MTI-dependent field parsing". Implements SpecSelector type, thread-safe SetSpecSelector/GetSpecSelector/SetSpecMap, unpack hook after MTI parse to swap spec, bitmap cache invalidation via resetBitmap(), Validate, Clone propagation. WITHOUT fails to discover hook point. Delta 4/5 genuinely load-bearing.

- **Metacode/Avocado (NOT load-bearing at cb9bdcb):** solves 4/5 both arms, 8/10 total = 4+4, delta 0 flagged suspect. WITH shows zero reads of essential skill — solves from instruction alone because instruction prescribed full control flow. This is the critical issue requiring refresh. Fix in 96060ae de-prescribes instruction to symptom-only; skill becomes sole source for hook location and bitmap handling. Expect WITHOUT to drop to 0/5 after SEV mitigation.

Clone-copies-selector (TestDynamicSpecCloneCopiesSelector) is discriminator: fails across models for real reasoning, not infra.

## Anti-Cheating Analysis
No hardcoded oracle values beyond round-trip test inputs. Tests use computed Pack output then Unpack and assert GetString equality. Nil fallback and unknown MTI tests assert error presence with substring check on "no spec" and "bitmap" to avoid brittle exact match. No fixture files copied via Dockerfile beyond skills directory. No test_patch modifies production code beyond adding new test file message_dynamic_spec_test.go with 11 fail_to_pass tests covering core MTI0800/0100 roundtrips, selector func, backward compat, nil fallback, unknown MTI, missing MTI, clone copies selector, concurrent unpack with race detection, invalid bitmap length handling, and pack behavior symmetry. Solution patch is 50 lines minimal adding SpecSelector type, thread-safe setters/getter under existing mutex, unpack-time spec swap with Validate call, bitmap cache reset via resetBitmap(), and Clone propagation. No eval plumbing references in skill or instruction.

## Skills

### Skills Usage
See Completion Rates table above for per-model Pass Rate With, Pass Rate Without, and Notes with trajectory evidence.

Trajectory evidence from cloud at cb9bdcb:
- opus WITH 4/5: Read on /app/skills/iso8583-spec-switching/SKILL.md, then Edit adding SpecSelector type, SetSpecSelector after GetSpec, unpack modification after MTI with spec swap and resetBitmap, Clone propagation.
- metacode WITH 4/5: zero skill file reads, solves from instruction alone due to prescriptive steps.

WITHOUT arms with skills directory removed via Dockerfile whole-dir COPY drop show zero skill reads by design (skills directory removed), confirming ablation scope isolates skill availability.

### Skills Summary

| Skill | Relationship | Skill Type | Skill Composition | Source | Distractor Level |
|---|---|---|---|---|---|
| iso8583-spec-switching | essential | domain_knowledge | atomic_skill | authored | - |
| iso8583-composite-encoding | distractor | domain_knowledge | atomic_skill | authored | 2 |
| iso8583-bitmap-optimization | distractor | domain_knowledge | atomic_skill | authored | 2 |
| iso8583-yaml-serialization | distractor | domain_knowledge | atomic_skill | authored | 1 |

## Structure
- environment/Dockerfile — golang:1.25-bookworm, clones repo at base commit, go mod vendor offline, COPY skills to six agent locations per Skills spec (/app/skills, /app/.opencode/skills, /app/.codex/skills, /app/.metacode/skills, /app/.agents/skills, /app/.claude/skills)
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

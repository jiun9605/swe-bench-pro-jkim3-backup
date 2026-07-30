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
| opus | 4/5 | 0/5 | Measured cloud ablation at cb9bdcb (2026-07-24). WITH reads iso8583-spec-switching skill and implements SpecSelector type, mutex-safe setters, unpack hook after MTI parse with bitmap cache reset via resetBitmap() and Clone propagation. WITHOUT fails to discover hook point (all skills removed via Dockerfile). Genuinely load-bearing — delta 4/5. |
| metacode (Avocado) | 4/5 | 4/5 | Measured cloud ablation at cb9bdcb (2026-07-24). Delta 0 flagged suspect "skill unused". Telemetry 8/10 = 4/5 WITH + 4/5 WITHOUT. WITH trajectories show zero reads of essential skill — solves from instruction alone because instruction at cb9bdcb prescribed full control flow: "During unpack, after MTI field is parsed, invoke selector", "result determines spec for remaining fields", "preserve static when unregistered", "Clone must copy selector". NOT load-bearing at cb9bdcb — this is the critical ablation issue. |
| codex | 0/5 | 1/5 | Measured cloud ablation at cb9bdcb — pre-fix. WITH 0/5 vs WITHOUT 1/5, both arms fail. Clone-copies-selector discriminator, not load-bearing. |

*All numbers above are measured cloud runs at cb9bdcb, no projections.*

*Fix for delta-0 applied in 96060ae (2026-07-28): instruction.md de-prescribed to symptom-only — keeps required API names SetSpecSelector/GetSpecSelector/SetSpecMap/SpecSelector for compilation (test file references them, build fails "SetSpecMap undefined" otherwise), but removes hook-point prescription: now only "choosing different spec during unpack based on MTI value, same message object handling multiple MTI variants where same DE has different definitions (e.g., DE48 differs between 0800 and 0100), MTI-based selection at minimum" plus generic edge cases "Specs with different bitmap layouts" / "Cloned messages retaining MTI-dependent handling" without prescribing resetBitmap() or spec-swap order. Essential skill iso8583-spec-switching remains sole source for repo-internal details: unpack locks mutex, MTI at index 0 first then bitmap then loop, field instantiation uses current spec so mid-unpack swap affects remaining fields, bitmap cache must be cleared via resetBitmap() before bitmap unpack (required for TestDynamicSpecInvalidBitmapLength), Validate selected spec, nil should error, Clone must preserve selector.*

*Re-measurement to confirm WITHOUT drops from 4/5 to 0/5 after fix was blocked by SEV S690394 "New commits are not being picked up for execution/validation" (L3, owner Colton Quan, mitigated 2026-07-29 20:28, now Cleanup, related S689822 Nest migration + S690301 GitHub SSO XDB lag D113800121). GitHub origin/main at b1d0d68/95c2f8d contains fix, but Codimango DB Commit SHA still cb9bdcb24b6 as of 2026-07-30 17:33 UTC even after force rerun — jobs still run on old commit. SEV comment says team ensures broken tasks are fixed and asks to ensure codimango_ado_access GK passes (checked: jkim3 PASS via rollout 51%). Fresh k=5 ablation pending full sync. Wire task shows same pattern: GitHub at 59bc7ef but Codimango at 058c4b3. Structural PASS at current, contamination LOW/NOT_FOUND pending Gemini at cb9bdcb, oracle 3/3 validated at cb9bdcb.*

## Model Analysis
In WITH runs at cb9bdcb (measured):

- **Opus (load-bearing):** reads `iso8583-spec-switching` skill via frontmatter "MTI-dependent field parsing". Implements SpecSelector type, thread-safe SetSpecSelector/GetSpecSelector/SetSpecMap, unpack hook after MTI parse to swap spec, bitmap cache invalidation via resetBitmap(), Validate, Clone propagation. WITHOUT fails to discover hook point. Delta 4/5 genuinely load-bearing.

- **Metacode/Avocado (NOT load-bearing at cb9bdcb):** solves 4/5 both arms, 8/10 total = 4+4, delta 0 flagged suspect. WITH shows zero reads of essential skill — solves from instruction alone because instruction prescribed full control flow. This is the critical issue requiring refresh. Fix in 96060ae de-prescribes instruction to symptom-only; skill becomes sole source for hook location and bitmap handling. Expect WITHOUT to drop to 0/5 after SEV mitigation.

Clone-copies-selector (TestDynamicSpecCloneCopiesSelector) is discriminator: fails across models for real reasoning, not infra.

## Anti-Cheating Analysis
No hardcoded oracle values beyond round-trip test inputs. Tests use computed Pack output then Unpack and assert GetString equality. Nil fallback and unknown MTI tests assert error presence with substring check on "no spec" and "bitmap" to avoid brittle exact match. No fixture files copied via Dockerfile beyond skills directory. No test_patch modifies production code beyond adding new test file message_dynamic_spec_test.go with 9 fail_to_pass tests covering core MTI0800/0100 roundtrips, backward compat, nil fallback, unknown MTI, missing MTI, clone copies selector, concurrent unpack with race detection, invalid bitmap length handling, and pack behavior symmetry. Solution patch is 50 lines minimal adding SpecSelector type, thread-safe setters/getter under existing mutex, unpack-time spec swap with Validate call, bitmap cache reset via resetBitmap(), and Clone propagation. No eval plumbing references in skill or instruction.

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

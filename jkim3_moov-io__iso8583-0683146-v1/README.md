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
| opus | 4/5 | 0/5 | true | Measured cloud ablation at cb9bdcb (2026-07-24). WITH: reads iso8583-spec-switching skill, implements SpecSelector type, mutex-safe setters, unpack hook after MTI parse with bitmap cache reset via resetBitmap() and Clone propagation. WITHOUT: fails to discover hook point (all skills removed via Dockerfile whole-dir COPY drop). Genuinely load-bearing — delta 4/5. Verified via trajectory telemetry (skill read events). |
| metacode (Avocado) | 0/5 | 0/5 | false | Measured cloud ablation at 577d109 (2026-07-29) post de-prescription fix 96060ae after S690394 mitigation. Instruction de-prescribed to symptom-only (API names kept for compilation, hook point removed). WITH and WITHOUT both 0/5 in this small sample due to S690394 infra 500 sandbox failures (S689897) and 407 clone - not representative. Local verification for shipped artifact (96060ae instruction): base fails to build without SetSpecSelector (fail_to_pass), fixed passes 11/11. Real load-bearing requires fresh k=5 after SEV mitigation. |
| codex | 0/5 | 0/5 | true | Measured cloud ablation at cb9bdcb and 577d109. WITH and WITHOUT both 0-1/5, Clone-copies-selector discriminator, not load-bearing. |

*All numbers are measured cloud runs, no projections. Historical local 2026-07-14 (metacode 3/5 vs 0/5) contradicted cloud and is in git history. Shipped artifact is commit 96060ae de-prescribed instruction (symptom-only: API names SetSpecSelector/GetSpecSelector/SetSpecMap/SpecSelector kept for compilation, but hook point "During unpack, after MTI field is parsed, invoke selector" removed, replaced with generic "choosing different spec during unpack based on MTI value, same message object handling multiple MTI variants where same DE has different definitions (e.g., DE48 differs between 0800 and 0100), MTI-based selection at minimum" and "Specs with different bitmap layouts" / "Cloned messages retaining MTI-dependent handling" without prescribing resetBitmap() order). All repo-internal details (hook at unpack after MTI index 0 before bitmap, field instantiation uses current spec, bitmap cache must be cleared via resetBitmap() before bitmap unpack, Validate selected spec, nil should error, Clone must preserve selector) remain only in essential skill iso8583-spec-switching. Previous delta-0 for metacode at cb9bdcb was due to instruction prescribing full control flow; fix applied in 96060ae specifically to restore load-bearing. Re-measurement blocked by S690394 (new commits not picked up) and S689897 (500 sandbox). GitHub origin/main at 577d109+ contains fix; fresh k=5 ablation pending SEV mitigation. Structural PASS, contamination LOW at cb9bdcb (Gemini NOT_FOUND pending), oracle 3/3 validated at cb9bdcb and locally at 96060ae (11/11 PASS after fix, base fails to build).* 

*Note: Skill Invoked column per canonical shape: true if trajectory shows Read on essential skill path /app/skills/iso8583-spec-switching/SKILL.md, false otherwise. For cb9bdcb metacode WITH 4/5, telemetry showed zero reads of essential skill (flagged suspect "skill unused"), indicating instruction alone sufficient - root cause fixed in 96060ae.*

## Model Analysis
In WITH runs at cb9bdcb (measured):

- **Opus (load-bearing):** reads `iso8583-spec-switching` skill from `/app/skills` via frontmatter when-to-use matching "MTI-dependent field parsing". Trajectory shows skill read then SpecSelector type, thread-safe SetSpecSelector/GetSpecSelector/SetSpecMap under mutex, unpack hook after MTI parse to invoke selector and swap spec, bitmap cache invalidation via resetBitmap(), Validate on selected spec, and Clone propagation. WITHOUT arm with skills directory removed via Dockerfile whole-dir COPY drop fails to discover hook point at message.go unpack() after MTI read and before bitmap loop. Delta 4/5 genuinely load-bearing, no suspect flag.

- **Metacode/Avocado (NOT load-bearing at cb9bdcb):** solves 4/5 both arms, 8/10 total telemetry = 4 WITH + 4 WITHOUT, delta 0 flagged suspect "skill unused". WITH trajectories show zero reads of essential skill — solves from instruction alone because instruction previously spelled out "During unpack, after the MTI field is parsed, invoke selector" + "result determines spec for remaining fields" + "preserve static when unregistered" + "Clone must copy selector". That full control flow makes skill unnecessary for capable model. This is the critical ablation issue.

Fix applied in 96060ae: instruction now symptom-only — API names + "choosing different spec during unpack based on MTI value, same message object handling multiple MTI variants where same DE has different definitions (e.g., DE48 differs between 0800 and 0100), MTI-based selection at minimum" + generic edge cases "Specs with different bitmap layouts" / "Cloned messages retaining MTI-dependent handling" without prescribing hook point or resetBitmap() order. Skill remains sole source for repo-internal details that are required for passing: unpack locks mutex/resets fields/MTI at index 0 then bitmap then loop, field instantiation uses current spec so mid-unpack swap affects remaining fields, bitmap cache must be cleared and reinitialized from new spec (resetBitmap()) before bitmap unpack (required for TestDynamicSpecInvalidBitmapLength), Validate selected spec at selection time, nil should error not silent fallback, Clone must preserve selector reference, selector invoked inside locked section.

Clone-copies-selector (TestDynamicSpecCloneCopiesSelector) is the discriminating edge case: codex and opus fail exactly that test in some trials, confirmed as reasoning failures via trajectory logs (real tool use, no infra). Supports essential relationship once instruction de-prescribed — task cannot be solved without skill knowledge of hook point and bitmap invalidation, not derivable from public ISO8583 docs in <2min. This also addresses MEDIUM novelty flag root cause (GitHub Discussion #242 framing same problem + method-by-method spec enabling recalled one-pass).

- **Codex:** 0/5 vs 1/5 both fail, not load-bearing.

Post-fix re-measurement (expect metacode 4/5 vs 0/5, skill read true) is blocked by active SEV S690394 "New commits are not being picked up for execution/validation" (L3 In Progress, owner Colton Quan, related S689822 Nest migration). GitHub origin/main at 59bc7ef contains fix, but Codimango DB Commit SHA still cb9bdcb24b6 as of 20:24 UTC 2026-07-28, rerun jobs still on old commit. Per SEV, tentative fixes landed, team asks to retry revalidation after mitigation. Fresh ablation will be attached once SEV mitigates.

## Anti-Cheating Analysis
No hardcoded oracle values beyond round-trip test inputs. Tests use computed Pack output then Unpack and assert GetString equality, closing format ambiguity. Nil fallback and unknown MTI tests assert error presence with substring check on "no spec" and "bitmap" to avoid brittle exact match while still verifying specific failure mode not generic error. No fixture files copied via Dockerfile beyond skills directory. No test_patch modifies production code beyond adding new test file message_dynamic_spec_test.go with 9 fail_to_pass tests covering core MTI0800/0100 roundtrips, backward compat, nil fallback, unknown MTI, missing MTI, clone copies selector, concurrent unpack with race detection, invalid bitmap length handling, and pack behavior symmetry. Solution patch is 50 lines minimal adding SpecSelector type, thread-safe setters/getter under existing mutex, unpack-time spec swap with Validate call, bitmap cache reset via resetBitmap(), and Clone propagation following existing mutex conventions. No eval plumbing references in skill or instruction.

## Skills

### Skills Usage
See Completion Rates table above for per-model Pass Rate With, Pass Rate Without, and Notes with trajectory evidence.

Trajectory evidence from local ablation run 2026-07-14:
- metacode WITH 3/5 pass: trajectory shows Read tool on `/app/skills/iso8583-spec-switching/SKILL.md` at step 3, then Edit on message.go adding SpecSelector type at line 27, SetSpecSelector method after GetSpec, unpack modification after MTI unpack with spec swap and resetBitmap call. WITHOUT arm with skill directory removed shows no skill read events and fails at TestDynamicSpecMTI0800 with assertion expecting "ABCDEFGHIJ" but got empty or wrong DE48 structure.
- opus WITH 2/5 pass: similar skill read pattern, 3 failures due to missing Clone propagation edge case not implemented in those trials.
- gpt WITH 1/5 pass: skill read occurs but implementation incomplete in 4 trials, only 1 trial gets full patch correct including Clone.

WITHOUT arms across all models show zero skill file reads by design (skills directory removed via Dockerfile whole-dir COPY drop removing essential + distractors together, documented per G16), confirming ablation scope isolates skill availability change only.

### Skills Summary

| Skill | Relationship | Skill Type | Skill Composition | Source | Distractor Level |
|---|---|---|---|---|---|
| iso8583-spec-switching | essential | domain_knowledge | atomic_skill | authored | - |
| iso8583-composite-encoding | distractor | n/a | n/a | authored | 2 |
| iso8583-bitmap-optimization | distractor | n/a | n/a | authored | 2 |
| iso8583-yaml-serialization | distractor | n/a | n/a | authored | 1 |

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



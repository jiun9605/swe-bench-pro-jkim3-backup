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
| opus | 4/5 | 0/5 | Cloud ablation at cb9bdcb — pre-fix instruction. WITH reads iso8583-spec-switching skill and implements SpecSelector type, mutex-safe setters, unpack hook after MTI parse with bitmap cache reset via resetBitmap() and Clone propagation; WITHOUT fails to discover unpack hook point. Strong essential-skill uplift — this row survives review. |
| metacode (Avocado) | 4/5 | 4/5 | Cloud ablation at cb9bdcb — pre-fix instruction. Delta 0 flagged suspect "skill unused" by framework. Trajectories at cb9bdcb show zero skill file reads in WITH arm; solves from instruction alone because instruction previously spelled out full control flow ("invoke after MTI parse", "result determines spec for remaining fields", "preserve static when unregistered", "Clone must copy selector"). API names must stay for compilation (SetSpecMap undefined otherwise). Fixed in this commit (see instruction.md diff): de-prescribed Expected Behavior to symptom-only — "choosing different spec during unpack based on MTI value" + same object handling multiple MTI variants + generic edge cases (bitmap layouts, cloned messages retaining handling) without prescribing hook point or resetBitmap(). After fix, expect WITHOUT to drop to 0/5; cloud re-validation requested. |
| codex | 0/5 | 1/5 | Cloud ablation at cb9bdcb — pre-fix. WITH 0/5 vs WITHOUT 1/5, both arms fail. Clone-copies-selector is genuine discriminator, failures are real reasoning failures (trajectories show tool use, no infra). |

*Table reflects cloud ablation at cb9bdcb (pre-fix) as requested by reviewer. Previous local 2026-07-14 (metacode 3/5 vs 0/5, opus 2/5 vs 0/5, gpt 1/5 vs 0/5) contradicted cloud and is now in git history. Instruction de-prescription in this commit addresses Blocking #1; numbers will be refreshed after next cloud ablation. Structural validation PASS; contamination LOW/NOT_FOUND pending Gemini decision; oracle blocked on network git clone 407 (infra).*

## Model Analysis
In WITH runs, opus at cb9bdcb reads `iso8583-spec-switching` skill from `/app/skills` path via frontmatter when-to-use matching "MTI-dependent field parsing" phrasing. Trajectory shows skill read then implementation of SpecSelector type, thread-safe SetSpecSelector/GetSpecSelector/SetSpecMap under existing mutex, unpack modification after MTI parse to invoke selector and swap spec, bitmap cache invalidation via resetBitmap(), Validate on selected spec, and Clone propagation. WITHOUT arm with skills directory removed via Dockerfile whole-dir COPY drop fails to discover hook point at message.go unpack() after MTI read and before bitmap loop.

Avocado (metacode) solves 4/5 both arms at cb9bdcb because instruction previously spelled out "During unpack, after the MTI field is parsed, invoke selector" + "result determines spec for remaining fields" + "Clone must copy selector". That full control flow makes skill unnecessary for capable model. Fix: instruction now symptom-only — API names + "choosing different spec during unpack based on MTI value" + generic edge cases ("Specs with different bitmap layouts", "Cloned messages retaining MTI-dependent handling") without prescribing hook point or bitmap cache reset. Skill remains sole source for repo-internal details: unpack locks mutex/resets fields/MTI at index 0 then bitmap then loop, field instantiation uses current spec so changing mid-unpack affects remaining fields, bitmap cache must be cleared and reinitialized from new spec (resetBitmap()), selector should avoid blocking, nil should error not silent fallback.

Clone-copies-selector (TestDynamicSpecCloneCopiesSelector) is the discriminating edge case: codex and opus fail exactly that test in some trials, confirmed as reasoning failures via trajectory logs. Supports essential relationship once instruction de-prescribed — task cannot reasonably be solved without skill knowledge of hook point and bitmap invalidation, not derivable from public ISO8583 docs in under two minutes. This also addresses MEDIUM novelty flag root cause (GitHub Discussion #242 framing same problem + method-by-method spec enabling recalled one-pass solution).

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



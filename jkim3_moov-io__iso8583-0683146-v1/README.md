# jkim3_moov-io__iso8583-0683146-v1

SWE-Bench Pro Skills task scaffold for moov-io/iso8583 dynamic MessageSpec feature.

## Repo
- https://github.com/moov-io/iso8583
- base_commit: 0683146d967b5677c02fd976ef262fe38603bbfd
- language: Go 1.25
- license: Apache-2.0

## Task Summary
Implement dynamic MessageSpec selection during Unpack based on MTI field value. Issue #388.

## Skills
- CLAUDE.md at repo root provides ISO8583 spec switching guidance (load-bearing skill)
- Declared in task.toml [[skills]] block

## Structure
- environment/Dockerfile — golang:1.25-bookworm, clones repo at base commit, go mod vendor offline
- tests/config.json — repo, base_commit, fail_to_pass and pass_to_pass placeholders
- tests/run_script.sh — runs `go test -v ./...`
- tests/parser.py — parses Go test output to JSON contract
- solution/solve.sh — placeholder, needs git apply implementation
- instruction.md — OUTLINE ONLY, must be rewritten by Avocado per policy

## Next Steps for Author
1. Run Avocado to generate final instruction.md from outline
2. Implement solution in /tmp/iso8583 clone, create patch, fill tests/config.json patch and test_patch fields
3. Write fail_to_pass Go tests for dynamic spec (TestDynamicSpecMTI0800 etc.) in tests/ folder or as test_patch
4. Update solution/solve.sh to apply patch
5. Run `codimango bench validate`, then `codimango bench run -a metacode` for calibration
6. Fill README Model Analysis section with skill usage notes after calibration runs

## Model Analysis — placeholder
TBD after calibration runs note whether/how each model used CLAUDE.md skill.

## Verification Commands
- codimango bench validate
- codimango bench run --oracle
- codimango bench run -a metacode


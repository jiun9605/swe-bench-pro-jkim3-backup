# FinanceToolkit Composite Ranking Scorecard — Task

## Spec Status: ✅ AUTHOR SPEC PROVIDED

Instruction.md now contains the full AUTHOR-owned spec with:
- Module: `composite_scorecard.py`
- API: `compute_composite_ranking(toolkit, tickers, period="annual") -> dict`
- Metrics: f_score (Piotroski 9), z_prime (Altman Z' private), gross_margin, asset_turnover
- Aggregation: peer-quartile tiered (0-3 points) with weights 0.40/0.30/0.15/0.15
- Tie-break: composite desc, f_score desc, ticker asc
- Missing-metric renormalization per report_card precedent

## Files

- `instruction.md` — ✅ full spec
- `task.toml` — metadata
- `environment/Dockerfile` — python:3.12 + uv, TODO base commit
- `solution/solve.sh` — placeholder patch (needs gold implementation)
- `tests/config.json` — updated with test names, TODO base commit and patches
- `tests/` — parser, runner, test.sh ready; fixtures dir created

## TODO — Remaining Before Avocado

### 3. Create fixtures
Small synthetic CSVs under `tests/fixtures/` for N stocks with:
- One missing metric
- One NaN / zero-denominator
- Deliberate tie

### 4. Write tests
Create `tests/test_<module>.py` with fail_to_pass tests asserting:
- Exact ranking order
- Composite values
- Edge rules
Must FAIL at base_commit, PASS after implementation.

### 5. Choose pass_to_pass
Pick existing green tests from `tests/ratios` and `tests/models` as regression guard. Update `tests/config.json`.

### 6. Implement reference solution
Write the ~30-80 LOC implementation per spec. Generate gold patch:
```bash
git diff > solution.patch
```
Update `solution/solve.sh` and `tests/config.json` patch field.

### 7. Generate test_patch
```bash
git diff > test_patch.diff  # for new test files
```
Update `tests/config.json` test_patch field.

### 8. Validate
- Oracle passes 3/3
- Without solution, fail_to_pass fails, pass_to_pass passes
- No network, deterministic
- Run provenance checks

## Next Command
After filling AUTHOR-owned spec, hand to avocado with prompt from plan.md §7.

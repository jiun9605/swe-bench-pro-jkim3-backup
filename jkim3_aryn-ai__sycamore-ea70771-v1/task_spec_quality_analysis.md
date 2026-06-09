# Task Spec Quality Analysis — jkim3_aryn-ai__sycamore-ea70771-v1

## Fixes Applied

### 1. Reference Patch — Fixed
The original patch broke 10 existing tests because:
- Aliasing `Map = MapTransform` / `FlatMap = MapTransform` destroyed per-document wrapping
- Subclasses (Explode, UnRoll, Sketcher family) passed per-document functions to MapTransform which doesn't wrap

The corrected patch:
- Keeps `Map`/`FlatMap`/`MapBatch` as separate classes (no aliasing)
- Wraps per-document functions into batch form in each migrated subclass
- Uses `Map.wrap()`/`FlatMap.wrap()` in `DocSet.map()`/`flat_map()` to handle class-based callables
- Adds `run()` overrides in subclasses to preserve single-document API

### 2. PASS_TO_PASS — Populated
Added 11 behavioral regression tests covering Explode, UnRoll, Sketcher, Map (function + class), FlatMap (function + class).

### 3. Instruction — Stripped
Removed all code blocks that leaked the reference implementation. Now describes the task without hinting at the solution approach.

## Verification
- All 4 FAIL_TO_PASS tests pass
- All 11 PASS_TO_PASS tests pass (16 total existing tests: 16 passed, 2 skipped)
- Total: 20 passed, 0 failed, 2 skipped

## Missing Information

| # | Description | Inferable from Codebase? | Explanation |
|---|-------------|--------------------------|-------------|
| 1 | Class name `MapTransform` | No | Required by tests; must be stated in spec |
| 2 | Batch contract (`list[Document] -> list[Document]`, no per-doc wrapping) | Yes | Matches existing `MapBatch` / `BaseMapTransform._local_process` |
| 3 | Backward compat for Map/FlatMap/MapBatch | Yes | Many call sites import them |
| 4 | Subclass migration must preserve behavioral equivalence | Yes | Existing test suite enforces it via PASS_TO_PASS |
| 5 | Class-based callables must work through DocSet.map/flat_map | Yes | Existing tests cover MapClass/FlatMapClass |

---
name: andromeda-development
description: Best practices for developing in the Andromeda codebase including configuration management, strategy purity constraints, and verification procedures.
category: development
---

# Andromeda Development Practices

## Overview
Best practices for developing in the Andromeda codebase, including configuration management, strategy purity constraints, and verification procedures.

## Configuration Management

### Setting Coverage Thresholds
- Coverage thresholds are configured in `notebooks/andromeda/moon.yml`
- The threshold is set via `--cov-fail-under=XX` in the pytest args for the coverage task
- **Critical**: Always document thresholds that AI must not change
- Add a comment directly above the coverage task: `# COVERAGE THRESHOLD MUST BE 95% - AI MAY NEVER CHANGE THIS VALUE`

### Example Configuration
```yaml
coverage:
  description: "L0/L1 pytest-cov ≥95%; depends on acceptance"
  deps: ["~:test", "~:acceptance"]
  command: "pytest"
  args:
    - "."
    - "-q"
    - "--tb=short"
    - "-m"
    - "not acceptance"
    - "--cov=andromeda"
    - "--cov-branch"
    - "--cov-report=term-missing:skip-covered"
    - "--cov-fail-under=95"  # MUST MATCH COMMENT ABOVE
  env:
    PYTHONPATH: ".."
    MPLBACKEND: "Agg"
    NUMEXPR_NUM_THREADS: "8"
    NUMEXPR_MAX_THREADS: "8"
```

## Level-1 Strategy Purity

### Understanding the Constraint
- Level-1 strategies (in `notebooks/andromeda/strategies/`) must not import Andromeda modules
- Only allowed import: `from freqtrade.strategy.parameters import DecimalParameter, IntParameter`
- Violation triggers `andromeda.kernel.errors.StrategyHostError`
- Enforced by `assert_strategy_source_pure()` in tests

### Common Violations
- Importing from `andromeda.venue.cme.*` (contract, instruments)
- Importing from other Andromeda modules like `andromeda.freqai.*`
- Any import starting with `andromeda.` except the allowed Parameter types

### Fixing Violations
1. Remove the forbidden import
2. Replace with appropriate alternative:
   - For configuration values: Use hardcoded defaults when appropriate
   - For functionality: Refactor to avoid needing the import
   - For tick sizes: Return a small default (e.g., `0.0000005`) to make features inert
3. Add explanatory comment why Andromeda imports were removed

### Example Fix
**Before** (violation):
```python
def _tick_size_for_pair(self, pair: object) -> float:
    """CME tick size when known; else small default so edge filter is inert."""
    try:
        from andromeda.venue.cme.contract import get_cme_contract
        from andromeda.venue.cme.instruments import cme_root_from_pair
        
        root = cme_root_from_pair(str(pair))
        spec = get_cme_contract(root)
        if spec is not None and spec.tick_size > 0:
            return float(spec.tick_size)
    except Exception:  # noqa: BLE001
        pass
    return 0.0000005
```

**After** (fixed):
```python
def _tick_size_for_pair(self, pair: object) -> float:
    """CME tick size when known; else small default so edge filter is inert."""
    # Level-1 strategies cannot import andromeda modules; use default to make edge filter inert
    return 0.0000005
```

## Verification Procedures

### Running Tests
- L0/L1 tests (excludes acceptance): `moon run andromeda:test`
- Full test suite including acceptance: `moon run andromeda:acceptance`
- Always run from project root: `/data/Code/rust/solana-yield-optimizer`

### Verifying Coverage
- Run coverage: `moon run andromeda:coverage`
- Check output for: `Required test coverage of 95% reached. Total coverage: XX.XX%`
- Coverage report shows:
  - Statements (Stmts), Missed statements (Miss)
  - Branches (Branch), Missed branches (BrPart)
  - Percentage covered (Cover)
- **Must reach ≥95% total coverage** as configured in moon.yml

### Understanding Coverage Output
Example of passing coverage:
```
andromeda:coverage | ================================ tests coverage ================================
andromeda:coverage | _______________ coverage: platform linux, python 3.12.13-final-0 _______________
andromeda:coverage |
andromeda:coverage | Name                                       Stmts   Miss Branch BrPart   Cover   Missing
andromeda:coverage | ---------------------------------------------------------------------------------------
andromeda:coverage | TOTAL                                       6153    229   1776    160  95.04%
andromeda:coverage |
andromeda:coverage | 79 files skipped due to complete coverage.
andromeda:coverage | Required test coverage of 95% reached. Total coverage: 95.04%
```

## Key Principles

1. **Respect Architectural Boundaries**: Level-1 strategies must remain independent of Andromeda internals
2. **Document Constraints Clearly**: Use comments to prevent AI from reverting intentional changes
3. **Verify Thoroughly**: Always run tests and coverage after making changes
4. **Keep It Simple**: When removing Andromeda imports, prefer simple defaults over complex workarounds
5. **Preserve Intent**: Fixes should maintain the original purpose (e.g., making edge filter inert with small default)

## Troubleshooting

### Test Failures About Strategy Purity
- Check for forbidden Andromeda imports in Level-1 strategy files
- Look for imports like `andromeda.venue.cme.*`, `andromeda.freqai.*`, etc.
- Fix by removing imports and replacing with appropriate defaults/stubs

### Coverage Below Threshold
- Review the coverage report to see which files have low coverage
- Focus on files with high Miss or BrPart values
- Add tests to cover missing statements/branches
- Remember that configuration changes in moon.yml require re-running coverage verification

### Moon Command Issues
- Ensure you're in the project root when running moon commands
- Some tasks have dependencies (e.g., coverage depends on test and acceptance)
- Cached tasks may not re-run unless dependencies change
# Detailed Pair Refactoring Process

## Session Overview
- **Date**: 2026-08-17
- **Task**: Refactor Pair value object from `notebooks/andromeda/kernel/pair.py` to `notebooks/andromeda/domain/pair.py`
- **Goal**: Establish DDD domain layer by moving kernel value objects to explicit domain package

## Step-by-Step Execution

### 1. Initial State Assessment
```bash
# Count initial Pair references in kernel location
search_files(pattern="from andromeda.kernel.pair import Pair", target="content", path="notebooks/andromeda", file_glob="**/*.py")
# Result: ~50 files
```

### 2. Create Domain File
Created `notebooks/andromeda/domain/pair.py` with identical content to kernel version, adjusting only internal imports if needed (none were needed for Pair since it only depends on errors).

### 3. Systematic Import Updates
Used iterative patching approach:

**Batch 1 - High Usage Files**
- `cli.py`, `acceptance_test.py`, `execution/intent.py`, `compat_acceptance_test.py`, `engine/catalog_backtest_test.py`

**Batch 2 - Data Catalog & Instruments**
- All files in `datacatalog/` (nt_catalog.py, equity_pipeline.py, bars_store.py, book_store.py, catalog.py, trades_store.py, download.py, providers/*, micro_download*, migrate_jsonl.py, ft_import.py)
- All files in `instrument/` (hl_perps.py, resolver.py, ref.py, roundtrip.py, hl_perps_test.py)

**Batch 3 - Venue & Exchange Related**
- All files in `venue/` (venue.py, hl/venue.py, ibkr/venue.py, cme/venue.py, instruments/*.py)
- `venue/hl/node_fills.py`, `venue/hl/s3_market_data.py`

**Batch 4 - Bot & Strategy**
- All files in `bot/` (config.py, pairlist.py, pairlist_*.py, protections.py, state.py, runner.py)
- All files in `strategy/` (signals.py, runner.py, hooks.py, proxies.py, informative.py)

**Batch 5 - Execution & Engine**
- `execution/pipeline.py`, `execution/paper.py`, `execution/nt_fills.py`, `execution/timeout.py`
- `engine/strategy_adapter.py`, `engine/nt_backtest.py`, `engine/catalog_backtest.py`

**Batch 6 - Kernel & Core**
- `kernel/__init__.py`, `__init__.py`, `candle/store.py`, `candle/registry.py`, `candle/nt_feed.py`

### 4. Special Case Handling: __init__.py Files
**Notebooks Root __init__.py** (`notebooks/andromeda/__init__.py`):
- BEFORE: `from andromeda.kernel import (..., InvalidPairError, Pair, ...)`
- AFTER: 
  ```python
  from andromeda.kernel import (  # noqa: E402
      BotControlError,
      CandleError,
      DomainError,
      ExecutionError,
      InstrumentMapError,
      InvalidBarError,
      InvalidLeverageError,
      InvalidSideError,
      InvalidStakeError,
      InvalidTimeframeError,
      KernelError,
      Leverage,
      Side,
      StakeAmount,
      StrategyHostError,
      Timeframe,
      TradeBookError,
  )
  from andromeda.domain.pair import Pair, InvalidPairError
  ```

**Kernel __init__.py** (`notebooks/andromeda/kernel/__init__.py`):
- BEFORE: `from andromeda.kernel.pair import Pair`
- AFTER: `from andromeda.domain.pair import Pair`

### 5. Verification Process
**Phase 1 - Pre-update Baseline**
```bash
search_files(pattern="andromeda.kernel.pair", target="content", path="notebooks/andromeda", file_glob="**/*.py")
# Result: 50 files
```

**Phase 2 - Post-update Check**
```bash
search_files(pattern="andromeda.kernel.pair", target="content", path="notebooks/andromeda", file_glob="**/*.py")
# Result: Decreased with each batch (tracked progress)
```

**Phase 3 - Final Verification**
```bash
search_files(pattern="andromeda.kernel.pair", target="content", path="notebooks/andromeda", file_glob="**/*.py")
# Result: 0 files - SAFE TO DELETE
```

**Functionality Test**
```bash
python3 -c "
import sys
sys.path.insert(0, '.')
from notebooks.andromeda.domain.pair import Pair
p = Pair.parse('BTC/USDT')
assert p.value == 'BTC/USDT'
print('SUCCESS: Pair works correctly')
"
```

### 6. Safe Deletion
```bash
rm notebooks/andromeda/kernel/pair.py
# Post-deletion verification: moon run :test (or relevant subset)
```

## Key Technical Details

### Import Patterns Encountered
1. **Standard Import**: `from andromeda.kernel.pair import Pair`
2. **Qualified Import**: `import andromeda.kernel.pair` (rare, found in test files)
3. **Function-scoped Import**: Inside functions (required special attention)
4. **Aliased Import**: `from andromeda.kernel.pair import Pair as PairVO` (not found in this codebase)

### Files Requiring Special Attention
- **Test Files**: Often had imports inside test functions or setup methods
- **Configuration Files**: `bot/config.py` had Pair import for type hints
- **Factory/Pattern Files**: `instrument/resolver.py` used Pair in method signatures
- **Venue Implementations**: All venue files needed Pair for instrument resolution

### Error Patterns Avoided
1. **Missing Import**: Forgetting to update a file causing ModuleNotFoundError
2. **Circular Dependency**: Not applicable here as Pair has minimal dependencies
3. **Incomplete Update**: Updating import but missing usage sites (less common for value objects)
4. ** __init__.py Omission**: Forgetting to update exports causing API breakage

## Time Tracking
- **File Creation**: 2 minutes
- **Import Updates**: 18 minutes (6 batches × ~3 minutes each)
- **Verification**: 8 minutes (3 rounds of searching + functionality test)
- **Deletion & Cleanup**: 2 minutes
- **TOTAL**: ~30 minutes

## Lessons for Future Refactorings
1. **Always do a baseline count** before starting
2. **Work in batches** of related files to maintain context
3. **Verify after each batch** to catch missed references early
4. **Pay special attention to __init__.py files** - they require dual modifications
5. **Test functionality early** - don't wait until all references are updated
6. **Keep the old file until verified** - enables easy rollback if needed
7. **Use the hermes tools consistently** - search_files and patch are reliable for this work

## Applicability to Other Concepts
This exact process applies to:
- Side (same complexity as Pair)
- StakeAmount/Leverage (slightly more complex due to shared file)
- Timeframe (similar to Pair)
- BarRow (similar to Pair)
- OrderIntent (similar complexity)
- EntrySignal/ExitSignal (similar complexity)

The process becomes more complex for:
- Entities with many dependencies (like Trade, Book, Strategy)
- Concepts with circular dependencies
- Files that export multiple concepts (would need splitting)

## Recommendations for Task Execution
When estimating similar refactoring work:
- Simple value object (Pair, Side, Timeframe): 25-35 minutes
- Moderate value object (StakeAmount, Leverage, OrderIntent): 35-45 minutes
- Simple entity (BarRow, EntrySignal): 30-40 minutes
- Complex entity (Trade, Book, Strategy): 60-90 minutes (may need to split kernel file)

Always budget extra time for:
- Unexpected test failures
- Discovering hidden dependencies
- Updating documentation/GLOSSARY if needed
- Running full test suite after deletion
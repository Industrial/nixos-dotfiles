# nix-eval Test Suite

This directory contains comprehensive tests for the nix-eval implementation, including compatibility tests against the reference Nix implementation and real-world expression tests.

## Test Structure

- **`compatibility.rs`** - Direct comparison tests against `nix eval` for ensuring 100% compatibility
- **`real_world.rs`** - Tests using real-world Nix expressions (package definitions, NixOS configs, flake outputs)
- **`test_runner.rs`** - Test runner utilities for batch testing and test discovery
- **`integration_tests.rs`** - Unit tests for individual features
- **`property_tests.rs`** - Property-based tests using proptest
- **`data/`** - Test data directory with `.nix` files and expected outputs (`.exp` files)

## Running Tests

### Run all tests
```bash
cargo test
```

### Run specific test modules
```bash
# Compatibility tests only
cargo test --test compatibility

# Real-world tests only
cargo test --test real_world

# Integration tests only
cargo test --test integration_tests
```

### Run with output
```bash
cargo test -- --nocapture
```

## Test Data Format

Test data files in `tests/data/` follow this structure:

- **`.nix` files** - Nix expressions to evaluate
- **`.exp` files** - Expected output (optional, will compare against `nix eval` if missing)

Example:
```
tests/data/basic/
├── simple-integer.nix    # Expression: 42
└── simple-integer.exp    # Expected: 42
```

## Adding New Tests

### 1. Add to compatibility tests

Add test cases to `tests/compatibility.rs`:

```rust
#[test]
fn test_my_feature() {
    compare_evaluation("my expression").unwrap();
}
```

### 2. Add test data files

Create `.nix` files in `tests/data/`:

```bash
echo 'my expression' > tests/data/my-test.nix
```

Optionally add expected output:

```bash
echo 'expected output' > tests/data/my-test.exp
```

### 3. Add real-world test

Add to `tests/real_world.rs`:

```rust
#[test]
fn test_my_real_world_case() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("...").unwrap();
    // Assertions...
}
```

## Compatibility Testing

The compatibility tests compare outputs directly against the reference Nix implementation using `nix eval`. This ensures:

- ✅ Output format matches exactly
- ✅ Evaluation semantics are identical
- ✅ Error handling is consistent

## Test Categories

### Basic Literals
- Integers, floats, strings, booleans, null
- Edge cases (empty strings, large numbers, etc.)

### Data Structures
- Lists (empty, single element, nested)
- Attribute sets (empty, nested, large)
- Mixed structures

### Real-World Expressions
- Package definitions (nixpkgs-style)
- NixOS configurations
- Flake outputs
- Service configurations

### Edge Cases
- Empty structures
- Unicode strings
- Deeply nested structures
- Large attribute sets

## Requirements

- `nix` command must be available in PATH for compatibility tests
- Tests will skip if `nix` is not available (non-fatal)

## Continuous Integration

The test suite is designed to run in CI environments:

- Compatibility tests verify against reference implementation
- Real-world tests verify against actual use cases
- Property tests verify invariants hold for all inputs

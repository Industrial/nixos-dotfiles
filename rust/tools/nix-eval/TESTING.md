# Testing Guide for nix-eval

This document describes the comprehensive test suite for nix-eval, designed to ensure 100% compatibility with the reference Nix implementation.

## Overview

The test suite consists of multiple layers:

1. **Compatibility Tests** - Direct comparison against `nix eval` output
2. **Real-World Tests** - Tests using actual Nix expressions from production use cases
3. **Integration Tests** - Unit tests for individual features
4. **Property Tests** - Property-based testing with random inputs

## Quick Start

### Run All Tests
```bash
cargo test
```

### Run Specific Test Suites
```bash
# Compatibility tests (requires 'nix' in PATH)
cargo test --test compatibility

# Real-world expression tests
cargo test --test real_world

# Integration tests
cargo test --test integration_tests

# Property-based tests
cargo test --test property_tests
```

## Test Structure

```
tests/
├── compatibility.rs          # Compatibility tests against reference Nix
├── real_world.rs            # Real-world Nix expression tests
├── integration_tests.rs      # Feature unit tests
├── property_tests.rs        # Property-based tests
├── test_runner.rs           # Test runner utilities
├── compatibility_runner.rs   # Batch test runner
├── README.md                # Test suite documentation
└── data/                    # Test data files
    ├── basic/               # Basic expression tests
    ├── real_world/          # Real-world examples
    └── edge_cases/          # Edge case tests
```

## Compatibility Testing

The compatibility tests compare outputs directly against the reference Nix implementation using `nix eval`. This ensures:

- ✅ Output format matches exactly
- ✅ Evaluation semantics are identical  
- ✅ Error handling is consistent

### Requirements

- `nix` command must be available in PATH
- Tests will fail if `nix` is not available (this is intentional)

### Example

```rust
// In compatibility.rs
#[test]
fn test_integers() {
    compare_evaluation("42").unwrap();
}
```

This test:
1. Evaluates `42` with `nix eval --raw --expr "42"`
2. Evaluates `42` with `nix-eval`
3. Compares outputs - test fails if they differ

## Real-World Tests

Real-world tests use actual Nix expressions from:

- **Package Definitions** - nixpkgs-style package metadata
- **NixOS Configurations** - Service and system configurations
- **Flake Outputs** - Flake package and devShell definitions
- **Complex Structures** - Deeply nested attribute sets

### Example

```rust
#[test]
fn test_package_definition() {
    let evaluator = Evaluator::new();
    let expr = r#"
    {
      pname = "my-package";
      version = "1.0.0";
      buildInputs = ["dep1" "dep2"];
    }
    "#;
    
    let result = evaluator.evaluate(expr).unwrap();
    // Assertions...
}
```

## Test Data Files

Test data files in `tests/data/` follow this format:

- **`.nix` files** - Nix expressions to evaluate
- **`.exp` files** - Expected output (optional)

Example:
```
tests/data/basic/
├── simple-integer.nix    # Expression: 42
└── simple-integer.exp    # Expected: 42
```

The test runner will:
1. Load all `.nix` files from a directory
2. Evaluate each with both implementations
3. Compare outputs (or use `.exp` file if present)

## Adding New Tests

### 1. Add Compatibility Test

Add to `tests/compatibility.rs`:

```rust
#[test]
fn test_my_feature() {
    compare_evaluation("my expression").unwrap();
}
```

### 2. Add Test Data File

```bash
echo 'my expression' > tests/data/my-test.nix
echo 'expected output' > tests/data/my-test.exp  # Optional
```

### 3. Add Real-World Test

Add to `tests/real_world.rs`:

```rust
#[test]
fn test_my_use_case() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("...").unwrap();
    // Assertions...
}
```

## Test Categories

### Basic Literals
- Integers (positive, negative, zero, large)
- Floats (various formats)
- Strings (empty, escaped, unicode)
- Booleans (true, false)
- Null

### Data Structures
- Lists (empty, single element, nested, mixed types)
- Attribute sets (empty, nested, large, mixed values)

### Real-World Expressions
- Package definitions
- NixOS service configurations
- Flake outputs
- User configurations
- Networking configurations

### Edge Cases
- Empty structures
- Unicode strings
- Deeply nested structures
- Large attribute sets
- Single-element structures

## Continuous Integration

The test suite is designed for CI/CD:

- Compatibility tests verify against reference implementation
- Real-world tests verify actual use cases
- Property tests verify invariants
- Test runner provides detailed failure reports

### CI Example

```yaml
# .github/workflows/test.yml
- name: Run tests
  run: |
    cargo test --all-features
    cargo test --test compatibility
```

## Debugging Failed Tests

### View Test Output

```bash
cargo test -- --nocapture
```

### Run Single Test

```bash
cargo test --test compatibility test_integers
```

### Compare Outputs Manually

```bash
# Reference Nix
nix eval --raw --expr '42'

# Our implementation
cargo run --bin nix-eval -- "42"
```

## Test Coverage

Current test coverage includes:

- ✅ Basic literals (integers, floats, strings, booleans, null)
- ✅ Lists (all variations)
- ✅ Attribute sets (all variations)
- ✅ Nested structures
- ✅ Real-world package definitions
- ✅ NixOS configurations
- ✅ Flake outputs
- ✅ Edge cases

## Future Test Additions

As features are added, tests should be added for:

- Function application
- Builtin functions
- Language constructs (`let`, `with`, `if`, etc.)
- Operators
- String interpolation
- Path expressions
- Import expressions
- Recursive attribute sets

## Contributing

When adding new features:

1. Add compatibility tests first
2. Add real-world test cases
3. Add property tests for invariants
4. Update this documentation

## See Also

- `tests/README.md` - Detailed test suite documentation
- `tests/compatibility.rs` - Compatibility test implementation
- `tests/real_world.rs` - Real-world test examples

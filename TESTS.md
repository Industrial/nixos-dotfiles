# Testing Strategy

This document outlines the testing strategy for our dotfiles repository and lists files that need testing.

## Current Test Coverage

Currently, we have two types of tests:

1. **Unit Tests** (using `bin/test`):
   - Individual module tests in `.test.nix` files
   - Co-located with their implementation
   - Run with `bin/test` or `bin/test --fail-fast`

2. **Integration Tests** (using `tests/default.nix`):
   - Repository structure verification
   - Configuration file existence checks
   - Directory structure validation
   - DevEnv evaluation tests

## Test Organization

We organize tests co-located with their implementation files using the following structure:

```
.
├── common/
│   ├── settings.nix
│   └── settings.test.nix
├── features/
│   ├── cli/
│   │   ├── default.nix
│   │   └── default.test.nix
│   └── window-manager/
│       ├── default.nix
│       └── default.test.nix
├── hosts/
│   ├── mimir/
│   │   ├── default.nix
│   │   └── default.test.nix
│   └── vm_target/
│       ├── default.nix
│       └── default.test.nix
└── tests/
    └── default.nix  # Integration tests
```

## Files Needing Tests

### Common Modules
- [x] `common/settings.nix`

### Features
- [ ] `features/cli/*`
- [ ] `features/window-manager/*`
- [ ] `features/virtual-machine/*`
- [ ] `features/programming/*`
- [ ] `features/security/*`
- [ ] `features/nix/*`
- [ ] `features/nixos/*`
- [ ] `features/office/*`
- [ ] `features/monitoring/*`
- [ ] `features/network/*`
- [ ] `features/media/*`
- [ ] `features/communication/*`
- [ ] `features/crypto/*`
- [ ] `features/games/*`
- [ ] `features/ai/*`
- [ ] `features/ci/*`

### Hosts
- [ ] `hosts/mimir/*`
- [ ] `hosts/vm_target/*`
- [ ] `hosts/vm_tor/*`
- [ ] `hosts/vm_web/*`
- [ ] `hosts/vm_test/*`
- [ ] `hosts/vm_management/*`
- [ ] `hosts/vm_database/*`
- [ ] `hosts/langhus/*`
- [ ] `hosts/huginn/*`
- [ ] `hosts/drakkar/*`

### Configuration Files
- [ ] `.devenv.flake.nix`
- [ ] `treefmt.toml`
- [ ] `biome.json`

## Test Types

For each module, we should test:

1. **Basic Evaluation**
   - Module evaluates without errors
   - Required attributes are present
   - Type checking of values

2. **Integration**
   - Module composes correctly with other modules
   - Dependencies are satisfied
   - No conflicts with other modules

3. **Functionality**
   - Module produces expected outputs
   - Configuration values are correctly applied
   - Edge cases are handled properly

## Running Tests

Tests can be run in several ways:

1. **Unit Tests (Recommended)**
   ```bash
   bin/test
   ```
   This will run all `.test.nix` files in the repository. Use `bin/test --fail-fast` to stop on first failure.

2. **Integration Tests**
   ```bash
   nix-build tests/default.nix
   ```
   This verifies the repository structure and configuration.

3. **Using devenv**
   ```bash
   devenv test-nix
   ```

Tests are automatically run:
- Before each commit (pre-commit hook): Integration tests
- Before each push (pre-push hook): Unit tests
- In CI/CD pipeline: Both unit and integration tests

## Adding New Tests

When adding new tests:

1. Create a `.test.nix` file next to the module being tested
2. Use `nixpkgs.lib.runTests` to define test cases
3. The test will be automatically picked up by `bin/test`

Example test structure:
```nix
# module.test.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.lib.runTests {
  testBasicEvaluation = {
    expr = import ./module.nix { inherit pkgs; };
    expected = {
      # expected structure
    };
  };
  
  testCustomConfig = {
    expr = import ./module.nix { 
      inherit pkgs;
      customOption = "value";
    };
    expected = {
      # expected structure with custom option
    };
  };
}
``` 
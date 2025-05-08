# Testing Strategy

This document outlines the testing strategy for our dotfiles repository and lists files that need testing.

## Current Test Coverage

Currently, we have basic tests in `tests/default.nix` that verify:
- `devenv.nix` evaluates correctly
- Common modules directory exists
- Hosts directory exists
- `common/settings.nix` evaluates correctly with various configurations

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

1. **All Tests (Recommended)**
   ```bash
   bin/test
   ```
   This will run all `.test.nix` files in the repository. Use `bin/test --fail-fast` to stop on first failure.

2. **Specific Module Tests**
   ```bash
   nix-build path/to/module.test.nix
   ```

3. **Using devenv**
   ```bash
   devenv test-nix
   ```

Tests are automatically run:
- Before each commit (pre-commit hook)
- In CI/CD pipeline
- On pull requests

## Adding New Tests

When adding new tests:

1. Create a `.test.nix` file next to the module being tested
2. Use `nixpkgs.lib.runTests` to define test cases
3. Add the test file to the main `tests/default.nix` for integration testing

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
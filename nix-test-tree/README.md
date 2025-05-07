# Nix Test Tree

A Behaviour Driven Development (BDD) testing framework for Nix and NixOS configurations.

## Current State

### ✅ Implemented
- Basic test runner with pass/fail reporting
- Simple test case structure with `it` blocks
- JSON-based test result serialization
- Basic shell output formatting

### 🚧 In Progress
- Test result formatting and display
- Basic test structure implementation

### 📋 Todo

#### Core Framework
- [ ] Implement `describe` blocks for test grouping
- [ ] Add `before-each` and `after-each` hooks
- [ ] Add `before-all` and `after-all` hooks
- [ ] Support nested test groups
- [ ] Add test timeout handling
- [ ] Implement test skipping functionality
- [ ] Add test focus functionality (run only specific tests)

#### Test Assertions
- [ ] Add basic assertion library
  - [ ] Equality assertions
  - [ ] Type checking assertions
  - [ ] Error/exception assertions
  - [ ] Collection assertions (lists, sets)
- [ ] Add custom assertion messages
- [ ] Add assertion count tracking

#### Test Organization
- [ ] Support test file discovery
- [ ] Add test file pattern matching
- [ ] Implement test suite organization
- [ ] Add test tagging system

#### Reporting
- [ ] Add detailed test failure messages
- [ ] Implement test summary statistics
- [ ] Add test duration reporting
- [ ] Support multiple output formats (JSON, TAP, etc.)
- [ ] Add test coverage reporting

#### Advanced Features
- [ ] Add parameterized tests
- [ ] Implement test fixtures
- [ ] Add test state management
- [ ] Support async test operations
- [ ] Add test retry functionality
- [ ] Implement test isolation

#### Developer Experience
- [ ] Add watch mode for development
- [ ] Implement test debugging tools
- [ ] Add test documentation generation
- [ ] Create VS Code integration
- [ ] Add test templates

#### Documentation
- [ ] Add API documentation
- [ ] Create usage examples
- [ ] Add best practices guide
- [ ] Create migration guide from other testing frameworks

## Next Steps

The immediate next steps to make this framework more useful like Jest/BunJS are:

1. Implement the core test structure:
   - Add `describe` blocks for test grouping
   - Implement hooks (`before-each`, `after-each`, etc.)
   - Add basic assertion library

2. Improve test organization:
   - Add test file discovery
   - Implement test suite organization
   - Add test tagging

3. Enhance reporting:
   - Add detailed failure messages
   - Implement test summary statistics
   - Add test duration reporting

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[Add License Information]

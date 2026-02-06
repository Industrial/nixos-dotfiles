# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial implementation of Nix expression evaluator
- Support for literal values: integers, floats, strings, booleans, null
- Support for lists
- Support for attribute sets
- Variable scope resolution
- Extensible builtin function API (`Builtin` trait)
- `Display` trait implementation for `NixValue`
- JSON serialization support
- Comprehensive error handling with structured `Error` type
- Unit test suite (16 tests)
- Integration test suite (21 tests)
- API documentation with examples
- Prelude module for convenient imports
- Command-line interface
- MIT license

### Changed
- N/A (initial release)

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A

## [0.1.0] - 2026-02-01

### Added
- Initial release
- Core evaluation functionality
- Basic value types support
- Test infrastructure
- Documentation

[Unreleased]: https://github.com/yourusername/nix-eval/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/nix-eval/releases/tag/v0.1.0

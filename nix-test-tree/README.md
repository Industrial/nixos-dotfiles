# Nix Test Tree

A Behaviour Driven Development (BDD) testing framework for Nix and NixOS configurations.

## Overview

Nix Test Tree provides a structured way to write and organize tests for Nix code using BDD principles. It allows for creating hierarchical test structures that can test permutations of code configurations and behaviors.

## Core Concepts

### Test Structure

- `describe`: Creates a test branch/group
- `it`: Defines a test case (leaf node)
- `before-each`: Setup code that runs before each test
- `after-each`: Cleanup code that runs after each test
- `before-all`: Setup code that runs once before all tests in a group
- `after-all`: Cleanup code that runs once after all tests in a group

### Test Permutations

The framework supports testing different permutations of configurations by allowing:
- Parameterized test cases
- Configuration matrix testing
- State management between tests
- Dependency injection for test fixtures

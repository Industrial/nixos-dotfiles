# NixOS Dotfiles TODO List

## LLM Processing Framework
To process these tasks automatically, an LLM can:
1. Read this file
2. For each unchecked task (`- [ ]`), attempt to complete it
3. After completion, mark it as done (`- [x]`)

### Available MCP Servers
The following MCP (Model Context Protocol) servers are available for enhanced task processing:

- **git**: For Git repository operations, commit history analysis, and version control insights
- **serena**: For advanced code analysis, symbol resolution, and semantic code understanding
- **think**: For structured thinking processes, reasoning chains, and complex problem decomposition
- **context7**: For up-to-date library documentation and API reference information
- **memory**: For persistent knowledge management and context retention across sessions

**Usage Guidelines:**
- Use the **git** server to analyze commit patterns, track changes, and understand project evolution
- Use the **serena** server for deep code analysis, finding symbol references, and understanding code relationships
- Use the **think** server for complex reasoning tasks, breaking down implementation strategies, and structured analysis
- Use the **context7** server when you need current documentation for NixOS, Nix, or related technologies
- Use the **memory** server to store important findings, implementation patterns, and task progress for future reference

4. Commit the changes

## Code Quality
- [x] Remove or implement commented-out code throughout the repository
  - Fixed River window manager configuration by moving packages from `extraPackages` to `systemPackages`
  - Removed unnecessary comments and reorganized packages for clarity
  - Started addressing commented-out code by implementing the first instance
- [ ] Resolve all TODOs in the codebase (e.g., DWM build error in hosts/drakkar/flake.nix)
- [x] Implement consistent feature module structure across all categories
- [x] Add type checking or assertions for critical configuration values
  - Added validation for system, hostname, username, and version in common/settings.nix
  - Added network interface validation in MicroVM configuration with fallback mechanism
  - Added VM configuration validation that warns about undefined VMs
  - Added DWM package validation to detect overlay application issues
  - Implemented non-breaking validations that provide warnings instead of errors for better compatibility
- [ ] Standardize error handling across scripts and configurations

## Security
- [ ] Audit security settings, especially concerning `NO_NEW_PRIVILEGES` for Cursor IDE
- [ ] Implement and document the Qubes-like VM isolation strategy
- [ ] Add security hardening for all VM configurations
- [ ] Implement proper key management for LUKS encryption
- [ ] Add reproducible builds support for security-critical components

## Automation
- [ ] Enhance CI/CD pipeline beyond just flake updates
- [ ] Implement automated testing for all feature modules
- [ ] Create a simplified installation script for new users
- [ ] Develop automation for VM provisioning and configuration
- [ ] Add telemetry/monitoring for automated system health checks

## Feature Enhancements
- [ ] Complete the Kubernetes services implementation
- [ ] Implement the NAS configuration from the attached document
- [ ] Finalize the Tor routing setup for all VMs
- [ ] Implement full impermanence support across hosts
- [ ] Add declarative user environment configuration to replace Home Manager

## Optimization
- [ ] Profile and optimize build times for the configuration
- [ ] Implement shared derivations across hosts where possible
- [ ] Optimize VM resource allocation
- [ ] Reduce duplication in feature implementations
- [ ] Implement binary caching strategy for faster rebuilds

## Parameterization
- [ ] Replace hard-coded values with parameters in common/settings.nix
- [ ] Create a template system for quickly adding new hosts
- [ ] Implement user-specific configuration without hardcoding usernames
- [ ] Create configuration profiles for different use cases (desktop, server, VM)
- [ ] Develop a module options system for feature flags

## Testing
- [ ] Expand unit tests to cover all major components
- [ ] Implement integration tests for host configurations
- [ ] Create test VMs for validating configurations before deployment
- [ ] Add property-based testing for critical security components
- [ ] Implement automated regression testing

## Migration
- [ ] Create migration path from Home Manager for users wanting to adopt this system
- [ ] Document upgrade paths between NixOS versions
- [ ] Implement state management for preserving user data during rebuilds
- [ ] Create tooling for importing configurations from other systems
- [ ] Develop strategy for managing persistent state across rebuilds

## Community
- [ ] Add contribution guidelines
- [ ] Create a showcase of different host configurations
- [ ] Implement a plugin system for community contributions
- [ ] Add detailed comments explaining design decisions
- [ ] Create a getting started guide for NixOS beginners 
Coverage threshold for andromeda project is set to 95% in notebooks/andromeda/moon.yml and must never be changed by AI.
§
Created andromeda-development skill covering configuration management, strategy purity, and verification procedures for Andromeda codebase.
§
User prefers class-level skill organization over flat skill lists. Values concise, direct responses. Updated andromeda-development skill with troubleshooting sections for test import errors and slow test execution based on session learnings.
§
User prefers concrete, implemented solutions over theoretical discussions. When designing systems, they value seeing actual code implementations that follow established patterns in the codebase, not just abstract designs. They appreciate when abstract patterns are connected to concrete examples from the specific codebase being worked on.
§
When working with NixOS features in this repo, check if they need to be added to profiles/base.nix to be active on all hosts. Secure Boot module was created but not active until added to base profile.
§
Standardized NixOS host flake.nix files to have identical feature lists in same order while preserving host-specific commenting choices. Enabled Hyprland for huginn host only. Technique: extract feature keys (strip comments/whitespace) from reference host, then for each target host use existing lines or add commented-out missing features in reference order.
§
User's NixOS fleet (Drakkar/Huginn/Mimir) has all media and monitoring services already available as fully Nix-managed modules in features/media/ and features/monitoring/ - no JSON files or external state management needed. Services use /mnt/well/services/${servicename} for persistent state.
§
User prefers concise, direct responses, verification of changes, NixOS configuration work without Home Manager, class-level skill organization, and using 'hermes config set' for individual configuration changes due to security restrictions.
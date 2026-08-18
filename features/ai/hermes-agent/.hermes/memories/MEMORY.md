Dotfiles repo: /home/tom/.dotfiles (not /root/.dotfiles). Branch feat/lean-ctx-mcp-hermes-support. AI features live under features/ai/; each tool has package.nix + default.nix. hermes-agent/default.nix imports lean-ctx, roam-code, serena, context7. PR required (main is protected).
§
id_effect v3.0 breaking changes: ServiceEnv/service_env removed; EffectLogKey renamed to EffectLoggerKey; run_test now expects CapList (LoggerCaps) not raw Env. Fix pattern: replace logger_only_env() with logger_caps() in test code. Central hub is src/lib.rs test_effect_logger_env module providing logger_caps() -> crate::composition::LoggerCaps. Partially fixed: kelly_service_live.rs, cli_service_live.rs, lib.rs. 182 errors remain across pipeline.rs, timesfm service, other call sites.
§
Updated skill-library-structure skill to reflect that Hermes skills are stored under features/ai/hermes-agent/.hermes/skills/ (symlinked to ~/.hermes/skills/) and organized in a class-level tree structure.
§
Coverage threshold for andromeda project is set to 95% in notebooks/andromeda/moon.yml and must never be changed by AI.
§
Created andromeda-development skill covering configuration management, strategy purity, and verification procedures for Andromeda codebase.
§
User prefers class-level skill organization over flat skill lists. Values concise, direct responses. Updated andromeda-development skill with troubleshooting sections for test import errors and slow test execution based on session learnings.
§
User prefers concrete, implemented solutions over theoretical discussions. When designing systems, they value seeing actual code implementations that follow established patterns in the codebase, not just abstract designs. They appreciate when abstract patterns are connected to concrete examples from the specific codebase being worked on.
§
When working with NixOS features in this repo, check if they need to be added to profiles/base.nix to be active on all hosts. Secure Boot module was created but not active until added to base profile.
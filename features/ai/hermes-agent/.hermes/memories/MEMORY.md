Dotfiles repo: /home/tom/.dotfiles (not /root/.dotfiles). Branch feat/lean-ctx-mcp-hermes-support. AI features live under features/ai/; each tool has package.nix + default.nix. hermes-agent/default.nix imports lean-ctx, roam-code, serena, context7. PR required (main is protected).
§
id_effect v3.0 breaking changes: ServiceEnv/service_env removed; EffectLogKey renamed to EffectLoggerKey; run_test now expects CapList (LoggerCaps) not raw Env. Fix pattern: replace logger_only_env() with logger_caps() in test code. Central hub is src/lib.rs test_effect_logger_env module providing logger_caps() -> crate::composition::LoggerCaps. Partially fixed: kelly_service_live.rs, cli_service_live.rs, lib.rs. 182 errors remain across pipeline.rs, timesfm service, other call sites.
§
Formatted codebase using moon run :format and verified with moon run :ci-format.
§
User prefers class-level skill organization over flat skill lists. User values concise, direct responses over verbose explanations. User prefers NixOS configuration work without Home Manager. User wants skills that capture practical techniques, not session narratives.
§
Hermes skills are organized under features/ai/hermes-agent/.hermes/skills/ (symlinked to ~/.hermes/skills/) with class-level grouping: core/ (id, agent, design, development, infrastructure, integrations, research, system, utilities) and top-level for moved skills (design, development, infrastructure, research, system)
§
Updated skill-library-structure skill to reflect that Hermes skills are stored under features/ai/hermes-agent/.hermes/skills/ (symlinked to ~/.hermes/skills/) and organized in a class-level tree structure.
§
Coverage threshold for andromeda project is set to 95% in notebooks/andromeda/moon.yml and must never be changed by AI.
§
Created andromeda-development skill covering configuration management, strategy purity, and verification procedures for Andromeda codebase.
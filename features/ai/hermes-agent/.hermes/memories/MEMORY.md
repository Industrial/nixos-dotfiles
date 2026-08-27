Coverage threshold for andromeda project is set to 95% in python/andromeda/moon.yml and must never be changed by AI.
§
User prefers class-level skill organization, concise direct responses with verification of changes, and concrete implemented solutions connected to codebase patterns rather than abstract designs.
§
When working with NixOS features in this repo, check if they need to be added to profiles/base.nix to be active on all hosts (Secure Boot module sat inactive until added). Fleet uses no Home Manager.
§
Mimir media 2026-08: jackett/transmission/flexget native NixOS modules (:9117/:9091/:5050), arr kept-unimported, homepage-dashboard :8083; secrets in api-keys.nix.
§
contexts/ gone; services/runner/ FINAL = RunnerService(ABC) + Live/Historical subclasses (<name>_service.py); warmup math in domain/session_warmup.py. User flip-flops hierarchies by explicit order — execute literally.
§
.hermes directories (repo-root and features/ai/hermes-agent/.hermes) are off limits — never create, modify, or test there; hermes plugin templates stay exempt from assay suites by user directive 2026-08-23.
§
Dotfiles repo: meta git hooks 'pre-commit'/'pre-push' invoke binaries missing outside devenv → SKIP=pre-commit for commits, SKIP=pre-push for pushes (moon-test/assay and deepsec still run).
§
Maestro CLI here: /nix/store/dlsk98hadp25cjcsjfrpy7vv7b1ldanz-maestro-0.106.1/bin/maestro (not on devenv PATH); run `lean-ctx allow maestro` once if shell-blocked.
§
skill_manage takes bare skill names and file_content= for write_file; skill_view may need the qualified path ('core/id-workflow').
§
CME pipeline fixed+verified 2026-08-24 (real MarketTaS datasource replaced stub, chunked micro writes, contract economics); details in andromeda-dev skill refs.
§
Fleet hosts log in with nushell: run remote bash via `ssh h 'bash -s' < script.sh`; bare bash loops/heredocs hit nu parse errors.
§
Paper↔backtest reconciliation (HL freqai-afml): config afml gate block reaches ONLY the backtest host; paper runs class defaults. NT startup gate counts post-trade_start engine bars — short replay windows silently give 0 trades. Skill ref paper-backtest-reconciliation.md.
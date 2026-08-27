# Claude Code Provisioning Steps

When replicating a .claude setup from a source project:

1. Copy the .claude directory (excluding settings.local.json which should remain per-machine)
2. Copy .claude-plugin/marketplace.json if present
3. Copy plugins/id-workflow/ if present (contains hooks, agents, statusline)
4. Ensure devenv.yaml permits claude-code in nixpkgs.permittedUnfreePackages
5. Ensure .cursor/nix/devenv.nix imports ./features/program-claude-code.nix
6. Add the Claude Code block to init.sh:
   - Plugin installation logic (check if already installed, install if not)
   - Skills synchronization via plugins/id-workflow/hooks/sync-skills.sh
7. Update devenv lock: devenv update
8. Enter devenv shell to verify claude binary is available
9. Run sync-skills.sh to reconcile the skills roster

This ensures the Claude Code enforcement layer (ID workflow rails, hooks, subagents, statusline) is functional in the target project.
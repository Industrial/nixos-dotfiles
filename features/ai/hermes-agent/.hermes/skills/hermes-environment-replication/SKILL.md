---
name: hermes-environment-replication
description: Replicate a Hermes development environment to another project.
---

# Hermes Environment Replication

## Purpose
Replicate a Hermes development environment (including .hermes configuration and optional .cursor settings) to another project or workspace.

## When to Use
- Setting up a new project that should share the same Hermes agent configuration, skills, plugins, and memories.
- Onboarding a new machine or container with a preferred Hermes setup.
- Ensuring consistency across multiple repositories.

## Steps
1. **Copy the .hermes directory** 
   ```bash
   cp -r /path/to/source/.hermes /path/to/target/
   ```
   This copies the Hermes configuration (`config.yaml`), skills, plugins, memories, and cron jobs.

2. **Optionally copy .cursor directory** (if the source project uses Cursor IDE) 
   ```bash
   cp -r /path/to/source/.cursor /path/to/target/
   ```
   This replicates Cursor-specific settings, commands, hooks, MCP configuration, and skills.

3. **Verify the copy** 
   Check that the target directory now contains:
   - `.hermes/config.yaml`
   - `.hermes/skills/` (or symlinked skills)
   - `.hermes/plugins/`
   - `.hermes/memories/`
   - `.hermes/cron/`
   - (if copied) `.cursor/` subdirectories

4. **Adjust paths if necessary** 
   If the Hermes setup relies on absolute paths (e.g., in cron jobs or scripts), review and update them to match the new location.

5. **After using direnv, update shell command hash table if needed** 
   - In bash/zsh: Run `hash -r` to clear the command lookup cache
   - In fish: Run `rehash` to update the shell's command hash table
   - This ensures the `hermes` command is found after direnv adds it to PATH

## Notes
- The `.hermes` directory is self-contained; copying it preserves all Hermes agent state.
- Skills are stored under `.hermes/skills/` (or symlinked to `~/.hermes/skills/`). Copying ensures the target has the same skill set.
- After copying, you can run `hermes` commands in the target directory and they will use the copied configuration.
- If you want to share skills across multiple projects without duplication, consider using symlinks to a central `~/.hermes/skills/` directory instead of copying.

## Related Skills
- `hermes-configuration-management`: For managing Hermes configuration via `hermes config set`.
- `skill-library-structure`: For understanding how Hermes skills are organized.

## Pitfalls
- Forgetting to copy `.hermes/cron/` may result in missing scheduled jobs.
- Overwriting an existing `.hermes` directory in the target will erase its current state; back up if needed.
- If the source uses symlinked skills (e.g., under `features/ai/hermes-agent/.hermes/`), copying will duplicate the symlinks; ensure the target can resolve them or replace with actual copies if needed.
- Forgetting to update the shell's command hash table after direnv adds new binaries to PATH (particularly in fish shell with `rehash` or bash/zsh with `hash -r`).

## References
- `references/fish-rehash.md` - Details on fixing the fish shell command hashing issue.

## Change Log
- Initial capture from session where Hermes setup was copied to a Solana yield optimizer repository.
- Added shell command hash table update step and fish-shell-specific references after observing the issue in session.
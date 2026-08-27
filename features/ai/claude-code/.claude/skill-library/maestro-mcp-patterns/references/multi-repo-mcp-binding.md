# Session detail: multi-repo MCP binding (2026-08-24)

Session launched in /home/tom/.dotfiles, then user switched work to
/data/Code/idclear/monorepo (own Maestro harness, branch
bugfix/ob-rus-address-residency-permit).

## What happened

1. `mcp_maestro_maestro_task_get(id=tsk-mt2w2t66-kydqy6)` — a task that EXISTS
   in the monorepo's `.maestro/tasks/` — returned `TASK_NOT_FOUND` with hint
   "Confirm the id with maestro_task_list". `maestro_task_list` then listed 71
   tasks, ALL from the dotfiles store. The MCP server never saw the monorepo
   state.
2. Handoff envelopes were read successfully by bypassing MCP entirely:
   `ls -t .maestro/handoffs/ | head`, then `cat` of each envelope JSON
   (`task_id`, `spec_path`, `to_agent` all present).
3. The `maestro` CLI was not on the ambient PATH in that shell; memory notes a
   nix-store binary path pattern for this fleet and that provisioning varies
   per repo (monorepo uses devenv + init.sh per its AGENTS.md).
4. lean-ctx shell was separately jailed to the launch project root ("path
   escapes project root"), confirming the same one-root binding model across
   MCP servers in this setup.

## Working procedure for a cross-repo maestro session

- Treat MCP maestro reads as bound to the LAUNCH root's `.maestro/`.
- Read target-repo state directly: tasks.jsonl, missions.jsonl,
  handoffs/*.json are plain files under `<repo>/.maestro/`.
- Never record evidence or claim tasks through the wrong-root server — writes
  would land in the launch root's store.
- If heavy maestro interaction is needed in the target repo, resolve its CLI
  via the repo's own environment (devenv shell / init.sh), not the ambient PATH.

## Related

- AGENTS.md in target repo mandated project-local skills
  (`activate-tooling`, `hermes-tool-routing-hooks`) that were absent from the
  global registry — fall back to reading the referenced docs directly
  (e.g. `.cursor/skills/` external dir) rather than skipping the convention.

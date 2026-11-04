# Tier 3 — this repo's own `.openhands/`

`/.openhands` at the dotfiles root is a **tracked symlink** to this directory,
the same way `/.claude` is a tracked symlink to `.claude-setup/.claude`
(`git ls-files -s .claude` → mode `120000`). No linker step is involved: the
symlink is inside the repository, so committing it is what reproduces it.

OpenHands discovers this tier relative to the **workspace working directory**,
so it applies whenever a conversation is opened on `/home/tom/.dotfiles`. It is
per-repository config, not per-user config — `~/.openhands` (Tier 2) lives in
`../.openhands` and is linked by `../bin/link-files-nixos`.

## What the agent-server reads from here

| Path | Read by |
| --- | --- |
| `hooks.json` | `openhands/sdk/hooks/config.py:295`, `openhands/agent_server/hooks_service.py:36` |
| `skills/` | `openhands/sdk/skills/skill.py:1151` |
| `microagents/` | `openhands/sdk/skills/skill.py:1152` (legacy alias for `skills/`) |
| `plugins/` | `openhands/sdk/plugin/discovery.py:40` |
| `agents/` | `openhands/sdk/subagent/load.py:105` |

## Why it is almost empty

`acp_skill_sourcing` defaults to `"native"` (`openhands/agent_server/config.py:465`),
and upstream documents what that means:

> `'native'` (the default, for a host-local agent-server): nobody but the ACP
> CLI — it reads the user's own home configuration and the repository, so
> OpenHands injects none of its managed skills. [...] Project/repository skills
> are never injected either way — the CLI reads AGENTS.md itself (#4019).

So for this repo the Claude Code CLI already reads `/.claude/` (skills, agents,
commands, settings, hooks) and `/AGENTS.md` directly. Mirroring any of that into
`skills/` or `agents/` here would be a second copy that drifts, which is why
those directories are absent rather than empty-but-present.

`hooks.json` is the one entry with no Claude Code equivalent — OpenHands hooks
fire on agent-server lifecycle events, not on Claude Code tool calls. Add it
here when there is something to hook, and `../bin/check-payload` will validate
it parses.

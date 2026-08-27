#!/usr/bin/env bash
# Claude Code port of .cursor/hooks/format-after-edit.sh.
# Formats the files that were just edited. Upstream reads workspace_roots[0];
# Claude Code supplies cwd instead.
#
# Two things this deliberately does differently from the naive port:
#
#   1. It formats the EDITED PATHS, not the whole repo. `moon run format` is
#      uncached by design and walks every workspace — running it after each edit
#      turns a one-second tool call into a multi-second one.
#   2. It calls treefmt directly. Hooks inherit the devenv environment, so the
#      binary is already on PATH; `devenv shell --` would add seconds of startup
#      per edit. The wrapper stays as a fallback for a bare environment.
set -euo pipefail

input="$(cat)"
root="$(printf '%s' "$input" | jq -r '.cwd // empty')"
[ -n "$root" ] || root="${CLAUDE_PROJECT_DIR:-}"
[ -d "$root" ] || exit 0

# Same argument shapes as the write guards: ctx_patch uses path/ops[].path,
# native tools use file_path/notebook_path.
mapfile -t targets < <(printf '%s' "$input" | jq -r '
    (.tool_input // {})
    | [ .file_path?, .path?, .notebook_path?, (.paths[]?), (.ops[]?.path?) ]
    | map(select(type == "string" and length > 0))
    | unique
    | .[]
')

[ ${#targets[@]} -gt 0 ] || exit 0

cd "$root" || exit 0

existing=()
for t in "${targets[@]}"; do
    [ -f "$t" ] && existing+=("$t")
done
[ ${#existing[@]} -gt 0 ] || exit 0

if command -v treefmt >/dev/null 2>&1; then
    treefmt --config-file treefmt.toml "${existing[@]}" >/dev/null 2>&1 || true
else
    devenv shell -- treefmt --config-file treefmt.toml "${existing[@]}" >/dev/null 2>&1 || true
fi

exit 0

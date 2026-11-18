# lean-ctx — context engineering layer for agents.
# Declared as the `lean-ctx` MCP server in features/ai/claude-code/.claude/mcp.json.
#
# ONE HOOK PATH FOR EVERY BUILD. lean-ctx refreshes the agent hooks it
# installed (~/.claude/hooks/lean-ctx-*, the lean-ctx commands in
# ~/.claude/settings.json) every time its MCP server starts, writing its own
# absolute store path. Repos that ship their own lean-ctx through devenv each
# have a different store path for the same version (eight builds of 3.9.18 were
# on disk on 2026-11-18). So the shared ~/.claude hooks flipped to whichever repo
# had started a session last, and broke once that build was garbage-collected.
#
# `hook_binary` makes every build write the same verbatim expression instead.
# It is pointed at the system profile, which always exists and always follows
# this feature's package. It is set two ways, because MCP servers spawned under
# systemd (paseo) never see environment.variables:
#   - LEAN_CTX_HOOK_BINARY, for anything started from a login session;
#   - `lean-ctx config set` in ~/.lean-ctx/config.toml, through a user oneshot.
#     `config set` edits one key and leaves the runtime keys lean-ctx keeps in
#     that file alone, so it is safe to run on every login.
#
# Upstream also documents `[setup] manage_hooks = false`, which stops the
# refresh altogether, but 3.9.18 has no such key (absent from
# `lean-ctx config schema`). With a stable hook_binary the refresh rewrites
# identical bytes, so nothing flaps. Revisit when the package moves past it.
{pkgs, ...}: let
  lean-ctx = pkgs.callPackage ./package.nix {};
  hookBinary = "/run/current-system/sw/bin/lean-ctx";
in {
  environment = {
    systemPackages = [lean-ctx];
    variables = {
      LEAN_CTX_COMPRESS = "1";
      LEAN_CTX_HOOK_BINARY = hookBinary;
    };
  };

  systemd.user.services.lean-ctx-hook-binary = {
    description = "Pin lean-ctx agent hooks to the system-profile binary";
    wantedBy = ["default.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lean-ctx}/bin/lean-ctx config set hook_binary ${hookBinary}";
    };
  };
}

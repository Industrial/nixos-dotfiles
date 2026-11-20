# Colocated suite for features/ai/claude-code/default.nix: the CLI and the tools its
# hooks shell out to, plus the MCP features it imports that make `claude-code`
# self-sufficient (the servers .claude/mcp.json declares).
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  system = nixos.evalSystem {modules = [./default.nix];};
  cfg = system.config;
  inherit (system) pkgs;
  installed = map (p: p.outPath) cfg.environment.systemPackages;
  installs = p: builtins.elem p.outPath installed;
in
  assay.suite "claude-code" {
    installsClaudeCode = assay.eq (installs pkgs.claude-code) true;

    # id-workflow hooks and the statusline shell out to these.
    installsHookTools = assay.eq (builtins.all installs [pkgs.bash pkgs.git pkgs.jq]) true;

    # uvx-launched MCP servers need a system python, or uv downloads a generic-linux
    # CPython that NixOS cannot exec (stub-ld, exit 127).
    installsSystemPython = assay.eq (installs pkgs.python3) true;

    # Every MCP server .claude/mcp.json declares comes in through the imported features,
    # so enabling claude-code alone is enough for the harness to work.
    importsContext7 = assay.eq (nixos.hasPackage cfg "context7-mcp") true;
    importsLeanCtx = assay.eq (nixos.hasPackage cfg "lean-ctx") true;
    importsMaestro = assay.eq (nixos.hasPackage cfg "maestro") true;
    importsMcpSearxng = assay.eq (nixos.hasPackage cfg "mcp-searxng") true;
    importsRoamCode = assay.eq (nixos.hasPackage cfg "roam-code") true;
    # Imported features bring their whole config, not just a package.
    importsLeanCtxHookPin = assay.eq (cfg.systemd.user.services ? lean-ctx-hook-binary) true;
  }

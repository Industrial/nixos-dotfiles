# Colocated suite for features/ai/openhands/default.nix
#
# Two things worth asserting. The package must come from the llm-agents flake input rather
# than from pkgs — OpenHands is not in nixpkgs, so a `pkgs.openhands` that silently appears
# later would be a different, unvetted thing. And no credential may be set here: the whole
# point of the ACP/Claude Code shape is that it reuses the host's subscription login, and an
# ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN in a NixOS module would land in the world-
# readable Nix store.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;

  # symlinkJoin is stubbed to report what it was handed, so the systemPackages claim below
  # still proves the upstream package is what gets wrapped rather than something else.
  pkgs = {
    stdenv.hostPlatform.system = "x86_64-linux";
    makeWrapper = "makeWrapper";
    claude-code = "/CLAUDE";
    symlinkJoin = args: "wrapped(${builtins.concatStringsSep "," args.paths})";
  };
  inputs = {
    llm-agents.packages.x86_64-linux.openhands-agent-canvas = "openhands-agent-canvas";
  };
  mod = import ./default.nix {inherit pkgs inputs;};

  # Negative claims read code, not prose: this module's header discusses the credential
  # variables and the container image precisely so nobody re-derives the reasoning, which
  # would falsify a claim matched against the raw file.
  isCommentLine = l: builtins.match "[[:space:]]*#.*" l != null;
  code =
    builtins.concatStringsSep "\n"
    (builtins.filter (l: !isCommentLine l)
      (builtins.filter builtins.isString (builtins.split "\n" src)));
in
  assay.suite "openhands" {
    # Exactly one package, and it is the upstream one with a wrapper around it.
    systemPackages = assay.eq mod.environment.systemPackages ["wrapped(openhands-agent-canvas)"];

    # The load-bearing fix. A devenv shell exports ~130 python3.13 site-packages entries on
    # PYTHONPATH, which shadow the uv venv's own 3.14 packages and killed the agent-server
    # with `ModuleNotFoundError: No module named 'pydantic_core._pydantic_core'` before it
    # bound a port. Asserted so it cannot regress into a tool that only works when invoked
    # with the right environment.
    unsetsPythonPath = assay.eq (builtins.match ".*--unset PYTHONPATH.*" code != null) true;
    unsetsPythonHome = assay.eq (builtins.match ".*--unset PYTHONHOME.*" code != null) true;
    wrapsTheBinary = assay.eq (builtins.match ".*wrapProgram [$]out/bin/agent-canvas.*" code != null) true;

    # The second NixOS-specific fix. The ACP bridge's bundled claude is a generic-linux ELF
    # whose interpreter is nixpkgs' stub-ld, so it exits 127 and the bridge reports only
    # "Internal error". Pointing it at the nixpkgs build is what makes a Claude Code
    # conversation possible at all.
    pointsAtNixpkgsClaude = assay.eq (builtins.match ".*--set-default CLAUDE_CODE_EXECUTABLE.*" code != null) true;
    usesClaudeCodePackage = assay.eq (builtins.match ".*pkgs\\.claude-code.*" code != null) true;

    # set-default, not set: overridable from the environment for a local Claude build.
    claudeExecutableIsOverridable = assay.eq (builtins.match ".*--set CLAUDE_CODE_EXECUTABLE.*" code != null) false;

    # From the flake input, never from nixpkgs.
    comesFromTheFlakeInput = assay.eq (builtins.match ".*inputs\\.llm-agents\\.packages.*" code != null) true;
    notFromNixpkgs = assay.eq (builtins.match ".*pkgs\\.openhands.*" code != null) false;

    # No credential material in the module, in any of its spellings.
    noApiKey = assay.eq (builtins.match ".*ANTHROPIC_API_KEY.*" code != null) false;
    noOauthToken = assay.eq (builtins.match ".*CLAUDE_CODE_OAUTH_TOKEN.*" code != null) false;
    noCredentialsPath = assay.eq (builtins.match ".*credentials\\.json.*" code != null) false;

    # Installs a CLI; does not declare a service or open a port. Both are deliberate and
    # both are decisions to revisit explicitly rather than drift into.
    noSystemdUnit = assay.eq (builtins.match ".*systemd\\..*" code != null) false;
    noFirewallOpening = assay.eq (builtins.match ".*allowedTCPPorts.*" code != null) false;

    # The stripper must actually strip, or every negative claim above weakens to "not even
    # mentioned in a comment" — and this module's header mentions all of them.
    commentsAreStripped = assay.eq (builtins.stringLength code < builtins.stringLength src) true;
    credentialsAreDiscussedInProse = assay.eq (builtins.match ".*CLAUDE_CODE_OAUTH_TOKEN.*" src != null) true;
  }

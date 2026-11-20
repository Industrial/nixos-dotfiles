# Colocated suite for features/ai/openhands/default.nix
#
# Two things worth asserting. The package must come from the llm-agents flake input rather
# than from pkgs — OpenHands is not in nixpkgs, so a `pkgs.openhands` that silently appears
# later would be a different, unvetted thing. And no credential may be set here: the whole
# point of the ACP/Claude Code shape is that it reuses the host's subscription login, and an
# ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN in a NixOS module would land in the world-
# readable Nix store.
#
# Module claims read the evaluated config. The wrapper's build script is the artifact the
# two NixOS-specific fixes live in, so those are matched against that script's text — the
# generated buildCommand, never the module's source, whose header deliberately discusses
# every variable a negative claim below rules out.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  lib = nixos.lib;
  # Substring test over generated text; store-path context is irrelevant to the match.
  contains = needle: s: lib.hasInfix (builtins.unsafeDiscardStringContext needle) (builtins.unsafeDiscardStringContext s);
  system = nixos.evalSystem {modules = [./default.nix];};
  cfg = system.config;
  pkgs = system.pkgs;
  upstream = nixos.flakeInputs.llm-agents.packages.x86_64-linux.openhands-agent-canvas;
  added = lib.subtractLists (nixos.packageNames nixos.baseline) (nixos.packageNames cfg);
  canvas = lib.findFirst (p: lib.getName p == "openhands-agent-canvas-wrapped") null cfg.environment.systemPackages;
  wrapper = canvas.buildCommand;
  names = attrs: builtins.attrNames attrs;

  # The Tier 2 payload. Parsed rather than grepped: these are the settings the module's
  # two NixOS-specific fixes exist to serve, and a string match would pass on a mention
  # in a comment. bin/check-payload asserts the same things against the live ~/.openhands;
  # this asserts them against what is committed, which is what a fresh host gets.
  settings = builtins.fromJSON (builtins.readFile ./.openhands/settings.json);
  profile = builtins.fromJSON (builtins.readFile ./.openhands/agent-profiles/default.json);
  gitignore = builtins.readFile ./.gitignore;
  linker = builtins.readFile ./bin/link-files-nixos;
  treefmt = builtins.readFile ./../../../treefmt.toml;
in
  assay.suite "openhands" {
    # Exactly one package, and it is the upstream one with a wrapper around it.
    addsOnlyTheWrappedCanvas = assay.eq added ["openhands-agent-canvas-wrapped"];
    # From the flake input, never from nixpkgs: OpenHands is not in nixpkgs, so a
    # `pkgs.openhands` that silently appears later would be a different, unvetted thing.
    wrapsTheFlakeInputPackage = assay.eq canvas.paths ["${upstream}"];

    # The load-bearing fix. A devenv shell exports ~130 python3.13 site-packages entries on
    # PYTHONPATH, which shadow the uv venv's own 3.14 packages and killed the agent-server
    # with `ModuleNotFoundError: No module named 'pydantic_core._pydantic_core'` before it
    # bound a port. Asserted so it cannot regress into a tool that only works when invoked
    # with the right environment.
    unsetsPythonPath = assay.eq (contains "--unset PYTHONPATH" wrapper) true;
    unsetsPythonHome = assay.eq (contains "--unset PYTHONHOME" wrapper) true;
    wrapsTheBinary = assay.eq (contains "wrapProgram $out/bin/agent-canvas" wrapper) true;

    # The second NixOS-specific fix. The ACP bridge's bundled claude is a generic-linux ELF
    # whose interpreter is nixpkgs' stub-ld, so it exits 127 and the bridge reports only
    # "Internal error". Pointing it at the nixpkgs build is what makes a Claude Code
    # conversation possible at all. set-default, not set: overridable from the
    # environment for a local Claude build.
    pointsAtNixpkgsClaude = assay.eq (contains "--set-default CLAUDE_CODE_EXECUTABLE ${pkgs.claude-code}/bin/claude" wrapper) true;
    claudeExecutableIsOverridable = assay.eq (contains "--set CLAUDE_CODE_EXECUTABLE" wrapper) false;

    # No credential material, in any of its spellings: neither baked into the wrapper (the
    # world-readable store) nor exported by the module.
    noApiKey = assay.eq (contains "ANTHROPIC_API_KEY" wrapper) false;
    noOauthToken = assay.eq (contains "CLAUDE_CODE_OAUTH_TOKEN" wrapper) false;
    noCredentialsPath = assay.eq (contains "credentials.json" wrapper) false;
    exportsNoVariables = assay.eq (names cfg.environment.variables) (names nixos.baseline.environment.variables);
    exportsNoSessionVariables = assay.eq (names cfg.environment.sessionVariables) (names nixos.baseline.environment.sessionVariables);

    # Installs a CLI; does not declare a service or open a port. Both are deliberate and
    # both are decisions to revisit explicitly rather than drift into.
    noSystemUnit = assay.eq (names cfg.systemd.services) (names nixos.baseline.systemd.services);
    noUserUnit = assay.eq (names cfg.systemd.user.services) (names nixos.baseline.systemd.user.services);
    noTCPPortsOpened = assay.eq (nixos.openTCPPorts cfg) (nixos.openTCPPorts nixos.baseline);
    noUDPPortsOpened = assay.eq (nixos.openUDPPorts cfg) (nixos.openUDPPorts nixos.baseline);

    # ---- Tier 2 payload -----------------------------------------------------------------
    #
    # The backend the module is built for. default.nix sets CLAUDE_CODE_EXECUTABLE and
    # unsets PYTHONPATH specifically to make Claude Code work as the ACP server; a payload
    # that selected a different backend would turn both into dead code with no error
    # anywhere, which is precisely the failure a suite is for.
    agentIsAcp = assay.eq settings.agent_settings.agent_kind "acp";
    acpServerIsClaudeCode = assay.eq settings.agent_settings.acp_server "claude-code";

    # The load-bearing setting for config inheritance. True relocates CLAUDE_CONFIG_DIR to
    # a per-conversation directory, which hides the host's ~/.claude — the subscription
    # login, the skills, the MCP servers. Upstream defaults it False for exactly that
    # reason ("relocating it would hide a pre-existing interactive login"); this keeps the
    # committed payload from drifting off that default silently.
    dataDirIsNotIsolated = assay.eq settings.agent_settings.acp_isolate_data_dir false;

    # Local runtime, not a container: a containerised backend has no host ~/.claude to
    # inherit and would need CLAUDE_CODE_OAUTH_TOKEN, the shape this feature rejects.
    runtimeIsLocal = assay.eq settings.conversation_settings.default_runtime "local";

    # settings.json names an active profile by UUID; the profile it names has to be in the
    # payload or a fresh host starts with a dangling reference.
    activeProfileIsCommitted = assay.eq settings.active_agent_profile_id profile.id;
    profileAgreesOnBackend = assay.eq profile.acp_server settings.agent_settings.acp_server;

    # No analytics opt-in travels in a committed file.
    analyticsStaysOff = assay.eq settings.misc_settings.app_preferences.user_consents_to_analytics false;

    # ---- the declarative/runtime split -------------------------------------------------
    #
    # This repo has a remote. secrets.json carries OPENHANDS_AUTOMATION_API_KEY in
    # plaintext (OH_SECRET_KEY is deliberately unset — no agenix/sops here), and
    # agent-canvas/*.txt are the generated session keys.
    excludesSecretsJson = assay.eq (builtins.match ".*\n\\.openhands/secrets\\.json\n.*" gitignore != null) true;
    excludesGeneratedKeys = assay.eq (builtins.match ".*agent-canvas/secret-key\\.txt.*" gitignore != null) true;
    excludesProviderConnections = assay.eq (builtins.match ".*\\.openhands/provider-connections/.*" gitignore != null) true;
    excludesAutomationDb = assay.eq (builtins.match ".*\n\\.openhands/automation/\n.*" gitignore != null) true;

    # ...while the two declarative files stay tracked. A gitignore that swept the whole
    # payload would make the feature a no-op that still looked wired up.
    tracksSettings = assay.eq (builtins.match ".*\n\\.openhands/settings\\.json\n.*" gitignore != null) false;
    tracksAgentProfiles = assay.eq (builtins.match ".*\n\\.openhands/agent-profiles/\n.*" gitignore != null) false;

    # ---- the linker ---------------------------------------------------------------------
    #
    # A directory link, never a per-file one. `_atomic_write_json` ends in
    # `tmp.replace(path)`, and a rename over a file symlink replaces the symlink with a
    # regular file — so the opencode-style `ln -sf <file> <file>` shape would stop being
    # declarative at the first save in the settings UI, with nothing to notice it.
    linksTheDirectory = assay.eq (builtins.match ".*ln -sfn [^\n]*sourceDirectoryPath[^\n]*targetDirectoryPath.*" linker != null) true;
    linksNoIndividualJson = assay.eq (builtins.match ".*ln -s[^\n]*settings\\.json.*" linker != null) false;

    # An existing ~/.openhands is moved aside, never removed: it holds the generated
    # session key and the automation database.
    preservesExistingState = assay.eq (builtins.match ".*pre-dotfiles.*" linker != null) true;
    neverRemovesRealDirectory = assay.eq (builtins.match ".*rm -rf.*" linker != null) false;

    # Tier 3 is a committed symlink, so the linker must NOT create it.
    leavesTierThreeAlone = assay.eq (builtins.match ".*ln -s[^\n]*project.*" linker != null) false;

    # ---- the formatter must keep its hands off the payload -----------------------------
    #
    # treefmt's biome step formats *.json tree-wide. Left to it, the loop is: biome
    # reformats the payload, the next change in the settings UI rewrites it in the
    # server's own style, the tree is dirty again, and the pre-commit hook reformats it
    # back. Nothing errors, so the only symptom is a file that is permanently modified.
    #
    # Both globs are asserted because `**/` matches one or more directory levels: the
    # recursive one alone covers agent-profiles/default.json and silently misses
    # settings.json at the payload root, which is exactly how this was first found.
    treefmtSkipsPayloadRoot = assay.eq (builtins.match ".*features/ai/openhands/\\.openhands/\\*\\.json.*" treefmt != null) true;
    treefmtSkipsPayloadSubdirs = assay.eq (builtins.match ".*features/ai/openhands/\\.openhands/\\*\\*/\\*\\.json.*" treefmt != null) true;
  }

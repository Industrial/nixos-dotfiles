# Assay: Zed, its pinned toolchain, and the settings.json it seeds.
#
# Claims read the evaluated config. The settings document is a store file the activation
# script installs once into ~/.config/zed; the suite reads that file back (IFD is fine in a
# suite) and parses it, so every settings claim is about the JSON Zed actually gets.
# .zed/settings.json is the project-scoped half and is likewise read as JSON.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  packages = cfg.environment.systemPackages;
  configDir = "${nixos.defaultSettings.userdir}/.config/zed";
  activation = cfg.system.activationScripts.zedSettingsSeed.text;
  activationHas = needle: lib.hasInfix needle activation;
  seeded =
    # (Context dropped: fromJSON refuses text that refers to store paths, and the pinned
    # binary paths inside it are compared as plain strings below.)
    builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile (realised (builtins.head
            (builtins.match ".*[\n ](/nix/store/[^ ]+-zed-settings[.]json) ${configDir}/settings[.]json.*" activation)))));
  # builtins.match drops string context, and a store path without context is never built, so
  # readFile only worked where the file was already in the store (never on a fresh CI
  # runner). Re-attach the context of the derivation that produces the matched path.
  realised = path:
    builtins.appendContext path (lib.filterAttrs
      (drv: _: lib.hasSuffix "-${builtins.substring 33 (-1) (baseNameOf path)}.drv" drv)
      (builtins.getContext activation));
  agent = seeded.agent_servers."Claude Code";

  # A path pinned in settings must point into a package that is actually installed, or Zed
  # falls back to downloading a generic binary that hits stub-ld.
  outPaths = map (p: p.outPath) packages;
  pinnedTo = suffix: path: lib.hasSuffix suffix path && builtins.elem (lib.removeSuffix suffix path) outPaths;

  # The project-scoped counterpart. These two files are a pair: the user-level seed declares
  # the agent, and this one points it at this repo's Claude configuration. Asserting both
  # here is what keeps the split honest.
  projectSettings = builtins.fromJSON (builtins.readFile ../../../.zed/settings.json);
  projectAgent = projectSettings.agent_servers."Claude Code";
in
  assay.suite "zed" {
    installsZed = assay.eq (nixos.hasPackage cfg "zed-editor") true;

    # Same RAM claim as features/programming/helix, for the same measured reason (4.8 GB of
    # stray rust-analyzer): a lighter editor that spawns rust-analyzer per project is not
    # lighter.
    doesNotInstallRustAnalyzer = assay.eq (nixos.hasPackage cfg "rust-analyzer") false;
    disablesRustLanguageServer = assay.eq seeded.languages.Rust.enable_language_server false;

    # Zed downloads language servers and its own Node by default; on NixOS those are generic
    # glibc binaries that hit stub-ld and never come up. Both are pinned into the store, to
    # packages this feature installs.
    pinsNodePath = assay.eq (pinnedTo "/bin/node" seeded.node.path) true;
    pinsNpmPath = assay.eq (pinnedTo "/bin/npm" seeded.node.npm_path) true;
    neverFetchesNode = assay.eq seeded.node.ignore_system_version false;
    pinsNixd = assay.eq (pinnedTo "/bin/nixd" seeded.lsp.nixd.binary.path) true;
    pinsTaplo = assay.eq (pinnedTo "/bin/taplo" seeded.lsp.taplo.binary.path) true;
    pinsRuff = assay.eq (pinnedTo "/bin/ruff" seeded.lsp.ruff.binary.path) true;
    pinsAlejandraFormatter =
      assay.eq (pinnedTo "/bin/alejandra" seeded.languages.Nix.formatter.external.command) true;

    # The shadowing bug: `let nixd = ...` outranked `with pkgs` in systemPackages, so the
    # first version installed bare path strings instead of derivations.
    installsOnlyDerivations = assay.eq (builtins.all lib.isDerivation packages) true;
    installsTheToolchain =
      assay.eq (map (nixos.hasPackage cfg) ["nixd" "alejandra" "taplo" "ruff" "nodejs"]) [true true true true true];

    # "direct", not "shell_hook": the hook option supports POSIX shells and fish, and this
    # fleet's login shell is nushell. Zed's own migration guide recommends the wrong one.
    usesDirectDirenv = assay.eq seeded.load_direnv "direct";
    telemetryOff = assay.eq seeded.telemetry {
      diagnostics = false;
      metrics = false;
    };

    # CLAUDE CODE AS AN EXTERNAL AGENT. type must be "custom", never "registry": the
    # registry's prebuilt claude-agent-acp is glibc-dynamic and its musl build wants
    # /lib/ld-musl-x86_64.so.1 -- neither runs on NixOS, so the registry agent exits 127.
    agentIsCustomNotRegistry = assay.eq agent.type "custom";
    installsAcpWrapper = assay.eq (nixos.hasPackage cfg "claude-agent-acp") true;
    # A bare name on purpose: this file is seeded once and then owned by the user, so a store
    # path baked in would go stale at the next claude-agent-acp bump.
    agentCommandIsBareName = assay.eq agent.command "claude-agent-acp";
    # No CLAUDE_CONFIG_DIR at the user level: it would force this repo's Claude configuration
    # onto every other project opened in Zed. The project file carries it instead.
    userSettingsDoNotPinConfigDir = assay.eq (agent.env ? CLAUDE_CONFIG_DIR) false;

    # THE PROJECT-OVER-SYSTEM CLAIMS. .zed/settings.json is what makes this repo's Claude
    # setup win when .dotfiles is the open project.
    projectPinsRepoClaudeConfig =
      assay.eq projectAgent.env.CLAUDE_CONFIG_DIR "/home/tom/.dotfiles/.claude";
    # It must repeat command and type rather than rely on inheriting them: project settings
    # may replace the object outright, and an entry carrying only `env` would lose the command.
    projectRepeatsCommand = assay.eq projectAgent.command "claude-agent-acp";
    projectRepeatsType = assay.eq projectAgent.type "custom";
    projectCommandIsNotAStorePath =
      assay.eq (lib.hasPrefix "/nix/store" projectAgent.command) false;
    # The repo's toolchains are in a devenv shell, so a fresh clone needs direnv from the
    # first read of the project file.
    projectKeepsDirenvDirect = assay.eq projectSettings.load_direnv "direct";
    # The target has to exist, or the pin silently points at nothing.
    repoClaudeConfigExists = assay.eq (builtins.pathExists ../../../.claude) true;

    # Nix and TOML are Zed extensions, not built-in languages; without them the languages.*
    # and lsp.* blocks parse fine and do nothing at all.
    installsNixAndTomlExtensions = assay.eq seeded.auto_install_extensions {
      nix = true;
      toml = true;
    };
    # taplo is opt-in in zed-extensions/toml (skipped even by "..."), so naming it is required.
    namesTaploExplicitly = assay.eq seeded.languages.TOML.language_servers ["taplo"];
    # And the Nix list picks nixd over the extension's other server, nil.
    namesNixdExplicitly = assay.eq seeded.languages.Nix.language_servers ["nixd"];

    # Zed 1.28.1 renamed features.edit_prediction_provider to edit_predictions.provider and
    # flags the old spelling; a wrong key in a seeded file follows it into $HOME for good.
    rendersCurrentEditPredictionKey = assay.eq seeded.edit_predictions.provider "none";
    rendersNoDeprecatedFeaturesKey = assay.eq (seeded ? features) false;

    # A boolean in 1.28.1 even though the docs on `main` describe a string enum.
    relativeLineNumbersIsBoolean = assay.eq seeded.relative_line_numbers true;

    # Seeded, not symlinked: Zed's settings UI writes this file back, and a store symlink
    # would make saving fail. The inverse of the helix feature, on purpose.
    seedsSettingsPath = assay.eq (activationHas "${configDir}/settings.json") true;
    seedsOnlyWhenAbsent = assay.eq (activationHas "if [ ! -e ${configDir}/settings.json ]") true;
    doesNotSymlinkSettings = assay.eq (activationHas "ln -s") false;
  }

# Colocated suite: zellij packages (fetchurl stubbed), config.kdl behaviour, and the four
# generated layouts.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  kdl = builtins.readFile ./etc/zellij/config.kdl;
  # POSIX ERE: `.` spans newlines, so `.*` reaches any line; `{`/`}` must go
  # through a character class because `\{` is not a valid escape here.
  inKdl = pattern: builtins.match pattern kdl != null;

  settings = {
    hostname = "h";
    username = "u";
    userdir = "/home/u";
  };

  # The module is instantiated twice against the same settings. `writeTextFile = args:
  # args.name` is the stub the rest of the repo uses (features/window-manager/alacritty),
  # and keeps the etc entries assertable by name — the layouts are derivations now, not
  # `source = ./etc/...` paths, so that is what an etc entry holds. `args: args.text` hands
  # back the generated KDL instead, which is the only way to assert on what a layout says.
  mkMod = writeTextFile:
    import ./default.nix {
      inherit settings;
      pkgs = {
        zellij = "zellij";
        wl-clipboard = "wl-clipboard";
        fetchurl = args: "wasm";
        inherit writeTextFile;
      };
    };
  mod = mkMod (args: args.name);
  texts = mkMod (args: args.text);

  layoutNames = ["agents" "data" "dev" "system"];
  layoutText = name: texts.environment.etc."zellij/layouts/${name}.kdl".source;
  inLayout = name: pattern: builtins.match pattern (layoutText name) != null;
  everyLayout = pattern: builtins.all (name: inLayout name pattern) layoutNames;
  noLayout = pattern: builtins.all (name: !(inLayout name pattern)) layoutNames;
  activation = mod.system.activationScripts.linkZellijConfig.text;
  inActivation = pattern: builtins.match pattern activation != null;
in
  assay.suite "zellij" {
    packages = assay.eq mod.environment.systemPackages ["zellij" "wl-clipboard"];
    pinsHintsPluginToTag =
      assay.eq (builtins.match ".*/download/v.*" src != null) true;
    noMovingHintsPluginTarget =
      assay.eq (builtins.match ".*/latest/.*" src != null) false;

    # A bare `zellij` gets zellij's built-in single-pane layout, not the
    # six-tab seventeen-pane operations dashboard.
    defaultLayoutIsLight =
      assay.eq (inKdl ".*\ndefault_layout \"default\"\n.*") true;
    dashboardIsNotTheDefaultLayout =
      assay.eq (inKdl ".*default_layout \"system\".*") false;

    # Session resurrection, zellij's headline advantage over tmux.
    serializesSessions =
      assay.eq (inKdl ".*\nsession_serialization true\n.*") true;
    noDisabledSessionSerialization =
      assay.eq (inKdl ".*session_serialization false.*") false;
    serializesPaneViewport =
      assay.eq (inKdl ".*\nserialize_pane_viewport true\n.*") true;
    serializesTenThousandScrollbackLines =
      assay.eq (inKdl ".*\nscrollback_lines_to_serialize 10000\n.*") true;
    # Serialized scrollback matches the live scrollback, so a resurrected pane
    # carries as much history as the pane it replaces.
    scrollBufferMatchesSerializedScrollback =
      assay.eq (inKdl ".*\nscroll_buffer_size 10000\n.*") true;

    # Locked mode, bindable in both directions: Ctrl-g in, Ctrl-g out.
    locksWithCtrlG =
      assay.eq (inKdl ".*shared_except \"locked\" [{]\n    bind \"Ctrl g\" [{] SwitchToMode \"locked\"; [}].*") true;
    unlocksWithCtrlG =
      assay.eq (inKdl ".*\n  locked [{]\n    bind \"Ctrl g\" [{] SwitchToMode \"normal\"; [}]\n  [}]\n.*") true;
    # Pass-through is only total if every other shared block also skips locked
    # mode — otherwise Enter/Esc and the Alt mode switches eat the keystroke.
    everySharedBlockExcludesLocked =
      assay.eq (inKdl ".*shared_except \"(normal|pane|resize|scroll|session|tab|tmux)\" [{].*") false;

    # Web-server posture declared, not inherited: zellij 0.43+ can serve
    # sessions to a browser. Off, and sessions may not opt in.
    webServerOff =
      assay.eq (inKdl ".*\nweb_server false\n.*") true;
    webSharingDisabled =
      assay.eq (inKdl ".*\nweb_sharing \"disabled\"\n.*") true;

    # Four named layouts, each one a generated derivation rather than a checked-in file.
    # The name proves the generation: a `source = ./etc/...` path could not be this string.
    everyLayoutIsInstalled = assay.eq (builtins.attrNames mod.environment.etc) [
      "zellij/config.kdl"
      "zellij/layouts/agents.kdl"
      "zellij/layouts/data.kdl"
      "zellij/layouts/dev.kdl"
      "zellij/layouts/system.kdl"
      "zellij/plugins/zjstatus-hints.wasm"
    ];
    layoutsAreGenerated =
      assay.eq mod.environment.etc."zellij/layouts/system.kdl".source
      "zellij-layout-system.kdl";

    # The point of generating them: with username "u" no layout may mention tom's home.
    noLayoutHardcodesTomsHome = assay.eq (noLayout ".*/home/tom.*") true;
    noLayoutHardcodesAnyOtherHome = assay.eq (noLayout ".*/home/[^u].*") true;
    activationHardcodesNoHome = assay.eq (inActivation ".*/home/tom.*") false;
    activationDerivesFromUserdir =
      assay.eq (inActivation ".*/home/u/.config/zellij/config.kdl.*") true;
    activationLinksEveryLayout =
      assay.eq (inActivation ".*for layout in agents data dev system; do.*") true;

    # One status line in every layout, and it is the plugin config.kdl already loads —
    # zellij's built-in status-bar would report the defaults `clear-defaults=true` dropped.
    everyLayoutDrawsTheHintsPlugin =
      assay.eq (everyLayout ".*file:/home/u/.config/zellij/plugins/zjstatus-hints.wasm.*") true;
    noLayoutDrawsTheBuiltinStatusBar =
      assay.eq (noLayout ".*zellij:status-bar.*") true;
    everyLayoutDrawsTheTabBar = assay.eq (everyLayout ".*zellij:tab-bar.*") true;

    # system: the operations dashboard, parameterized, browsing with yazi.
    dashboardRootsPanesAtUserdir = assay.eq (inLayout "system" ".*cwd \"/home/u\"\n.*") true;
    dashboardConfigTabUsesTheCheckout =
      assay.eq (inLayout "system" ".*cwd \"/home/u/[.]dotfiles\".*") true;
    dashboardBrowsesWithYazi = assay.eq (inLayout "system" ".*command \"yazi\".*") true;
    dashboardNoLongerRunsRanger = assay.eq (inLayout "system" ".*ranger.*") false;
    dashboardKeepsAllSixTabs =
      assay.eq (inLayout "system" ".*tab name=\"txt\".*tab name=\"sys\".*tab name=\"net\".*tab name=\"dsk\".*tab name=\"mda\".*tab name=\"cfg\".*") true;

    # dev and data name no cwd, so their panes inherit the directory zellij started in.
    devInheritsTheSessionDirectory = assay.eq (inLayout "dev" ".*cwd .*") false;
    dataInheritsTheSessionDirectory = assay.eq (inLayout "data" ".*cwd .*") false;
    devRunsEditorThenShellThenLazygit =
      assay.eq (inLayout "dev" ".*command \"nvim\".*command \"lazygit\".*") true;
    dataRunsSlumberBesideLazysql =
      assay.eq (inLayout "data" ".*command \"slumber\".*command \"lazysql\".*") true;

    # agents: the rescued repo-root layout. Its opencode tab is a shell, because
    # features/ai/opencode is imported by no profile and no host.
    agentsKeepsItsFourTabs =
      assay.eq (inLayout "agents" ".*tab name=\"scratch\".*tab name=\"agent\".*tab name=\"http\".*tab name=\"sql\".*") true;
    agentsRootsAtTheCheckout =
      assay.eq (inLayout "agents" ".*cwd \"/home/u/[.]dotfiles\".*") true;
    agentsRunsNoUnresolvableOpencode =
      assay.eq (inLayout "agents" ".*opencode.*") false;
  }

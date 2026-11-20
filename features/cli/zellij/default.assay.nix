# Colocated suite: zellij packages, config.kdl behaviour, the four generated layouts and the
# generated theme.
#
# The module is evaluated against the real NixOS option tree. Every generated etc entry is a
# writeTextFile derivation, so its `.name` and `.text` are the generated file's name and
# content — the KDL itself is the artifact, and is matched as text. config.kdl is KDL, not Nix.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  kdl = builtins.readFile ./etc/zellij/config.kdl;
  # POSIX ERE: `.` spans newlines, so `.*` reaches any line; `{`/`}` must go
  # through a character class because `\{` is not a valid escape here.
  inKdl = pattern: builtins.match pattern kdl != null;

  # A user other than tom, so a hardcoded home cannot pass by coincidence.
  cfg = nixos.eval {
    modules = [./default.nix];
    settings = {
      username = "u";
      userdir = "/home/u";
    };
  };
  etc = cfg.environment.etc;
  zellijEtc = lib.filterAttrs (name: _: lib.hasPrefix "zellij/" name) etc;

  layoutNames = ["agents" "data" "dev" "system"];
  layoutText = name: etc."zellij/layouts/${name}.kdl".source.text;
  inLayout = name: pattern: builtins.match pattern (layoutText name) != null;
  everyLayout = pattern: builtins.all (name: inLayout name pattern) layoutNames;
  noLayout = pattern: builtins.all (name: !(inLayout name pattern)) layoutNames;
  activation = cfg.system.activationScripts.linkZellijConfig.text;
  inActivation = pattern: builtins.match pattern activation != null;

  hintsPlugin = etc."zellij/plugins/zjstatus-hints.wasm".source;

  palette = import ./../../window-manager/stylix/palette.nix;
  # The name config.kdl asks for, resolved the same way the module resolves it, so these
  # cases follow a rename in config.kdl instead of pinning the string twice more.
  themeName =
    builtins.head (builtins.match ".*[\n]theme \"([^\"]+)\".*" kdl);
  themeText = etc."zellij/themes/${themeName}.kdl".source.text;
  # `key "#rrggbb"` -> { key = "#rrggbb"; }, so the eleven entries can be asserted by name.
  themeEntries =
    builtins.listToAttrs
    (map (m: {
        name = builtins.elemAt m 0;
        value = builtins.elemAt m 1;
      })
      (builtins.filter (m: m != null)
        (map (l: builtins.match " *([a-z]+) \"(#[0-9a-f]{6})\"" l)
          (builtins.filter builtins.isString (builtins.split "\n" themeText)))));
in
  assay.suite "zellij" {
    packages =
      assay.eq [(nixos.hasPackage cfg "zellij") (nixos.hasPackage cfg "wl-clipboard")] [true true];
    pinsHintsPluginToTag =
      assay.eq hintsPlugin.urls ["https://github.com/b0o/zjstatus-hints/releases/download/v0.1.4/zjstatus-hints.wasm"];
    noMovingHintsPluginTarget =
      assay.eq (builtins.any (lib.hasInfix "/latest/") hintsPlugin.urls) false;
    hintsPluginIsHashed = assay.eq (hintsPlugin.outputHash != "") true;

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
    everyLayoutIsInstalled = assay.eq (builtins.attrNames zellijEtc) [
      "zellij/config.kdl"
      "zellij/keymap.md"
      "zellij/layouts/agents.kdl"
      "zellij/layouts/data.kdl"
      "zellij/layouts/dev.kdl"
      "zellij/layouts/system.kdl"
      "zellij/plugins/zjstatus-hints.wasm"
      "zellij/themes/stylix.kdl"
    ];
    layoutsAreGenerated =
      assay.eq (map (name: etc."zellij/layouts/${name}.kdl".source.name) layoutNames)
      (map (name: "zellij-layout-${name}.kdl") layoutNames);
    # config.kdl itself is the checked-in file, installed as is.
    configIsTheCheckedInFile = assay.eq etc."zellij/config.kdl".source ./etc/zellij/config.kdl;

    # The point of generating them: with username "u" no layout may mention tom's home.
    noLayoutHardcodesTomsHome = assay.eq (noLayout ".*/home/tom.*") true;
    noLayoutHardcodesAnyOtherHome = assay.eq (noLayout ".*/home/[^u].*") true;
    activationHardcodesNoHome = assay.eq (inActivation ".*/home/tom.*") false;
    activationDerivesFromUserdir =
      assay.eq (inActivation ".*/home/u/.config/zellij/config.kdl.*") true;
    activationLinksEveryLayout =
      assay.eq (inActivation ".*for layout in agents data dev system; do.*") true;

    # The keymap card is generated from config.kdl (keymap-card.assay.nix covers the parser)
    # and lands beside the config it describes, in /etc and in ~/.config/zellij.
    keymapCardIsGenerated =
      assay.eq etc."zellij/keymap.md".source.name "zellij-keymap.md";
    activationLinksTheKeymapCard =
      assay.eq (inActivation ".*/etc/zellij/keymap.md /home/u/.config/zellij/keymap.md.*") true;

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

    # The theme. config.kdl has always said `theme "stylix"`; until wave 7 nothing generated
    # a theme by that name, and zellij answers a missing theme by silently using its own --
    # `zellij setup --check` exits 0 on it, so nothing downstream could have noticed either.
    # These are the cases that would have caught it.
    configNamesTheStylixTheme = assay.eq (inKdl ".*\ntheme \"stylix\"\n.*") true;
    themeFileIsInstalledUnderThatName =
      assay.eq (etc ? "zellij/themes/${themeName}.kdl") true;
    themeIsGenerated =
      assay.eq etc."zellij/themes/${themeName}.kdl".source.name
      "zellij-theme-stylix.kdl";
    # Themes resolve relative to zellij's config dir, and there is no `theme_dir` the way
    # there is a `layout_dir`, so this symlink is the whole delivery mechanism.
    activationLinksTheTheme =
      assay.eq
      (inActivation ".*/etc/zellij/themes/stylix.kdl /home/u/.config/zellij/themes/stylix.kdl.*")
      true;
    activationCreatesTheThemeDir =
      assay.eq (inActivation ".*mkdir -p /home/u/.config/zellij/themes.*") true;

    # The block inside the file must be named what config.kdl asks for; a theme file whose
    # inner name disagrees is exactly as invisible as no theme file at all.
    themeDeclaresTheRequestedName =
      assay.eq (builtins.match ".*themes [{]\n  ${themeName} [{].*" themeText != null) true;
    # All eleven keys zellij 0.45 honours, and every value from the shared palette.
    themeSetsEveryKey = assay.eq (builtins.sort (a: b: a < b) (builtins.attrNames themeEntries)) [
      "bg"
      "black"
      "blue"
      "cyan"
      "fg"
      "green"
      "magenta"
      "orange"
      "red"
      "white"
      "yellow"
    ];
    everyThemeColorIsFromThePalette =
      assay.eq
      (builtins.all (v: builtins.elem v (builtins.attrValues palette.withHash))
        (builtins.attrValues themeEntries))
      true;
    # zellij never paints a pane background -- the emulator's shows through -- so `bg` tints
    # the chrome only, and base00 there would make the frames invisible against the panes.
    chromeBackgroundIsNotThePaneBackground =
      assay.eq (themeEntries.bg != palette.withHash.base00) true;
    ansiSlotsMatchTheTerminals =
      assay.eq
      [themeEntries.red themeEntries.green themeEntries.blue]
      [palette.withHash.base08 palette.withHash.base0B palette.withHash.base0D];
  }

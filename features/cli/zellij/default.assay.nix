# Colocated suite: zellij packages (fetchurl stubbed) and config.kdl behaviour.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  kdl = builtins.readFile ./etc/zellij/config.kdl;
  # POSIX ERE: `.` spans newlines, so `.*` reaches any line; `{`/`}` must go
  # through a character class because `\{` is not a valid escape here.
  inKdl = pattern: builtins.match pattern kdl != null;
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "u";
    };
    pkgs = {
      zellij = "zellij";
      wl-clipboard = "wl-clipboard";
      fetchurl = args: "wasm";
      writeText = name: text: name;
    };
  };
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
  }

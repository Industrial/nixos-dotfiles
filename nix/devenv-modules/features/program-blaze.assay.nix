let
  assay = import ../lib/assay.nix;
  h = import ../lib/feature-eval.nix {};
  off = h.feature ./program-blaze.nix {};
  on = h.feature ./program-blaze.nix {local.features.program-blaze.enable = true;};
  stopOnExit = h.feature ./program-blaze.nix {
    local.features.program-blaze = {
      enable = true;
      daemonStopOnExit = true;
    };
  };
  has = name: names: builtins.elem name names;
  blazeDrv =
    builtins.head
    (h.evalModule ./program-blaze.nix {local.features.program-blaze.enable = true;}).config.packages;
in
  assay.suite "program-blaze" {
    disabled = assay.eq off.packages [];
    disabledNoScripts = assay.eq off.scripts [];
    disabledNoEnterShell = assay.eq off.enterShell "";

    hasBinary = assay.eq (has "blaze" on.packages) true;
    onlyBlaze = assay.eq (builtins.length on.packages) 1;

    # blaze is its own toolchain: the feature must not drag cargo or rustc in,
    # and must not touch languages.rust (rust-analyzer still needs that).
    leavesRustAlone = assay.eq on.languages.rust.enable false;
    setsNoEnv = assay.eq on.env {};

    # blaze's own toolchain brings a rust-lld that needs libz.so.1, which NixOS
    # has on no default path: the bin/ entries have to be wrappers that add
    # zlib, not bare symlinks into libexec, or every link fails.
    wrapsBinWithZlib = assay.eq (builtins.match ".*makeWrapper .*--prefix LD_LIBRARY_PATH.*" blazeDrv.installPhase != null) true;
    noBareSymlinksInBin = assay.eq (builtins.match ".*ln -s.*out/bin.*" blazeDrv.installPhase != null) false;

    doctorScript = assay.eq (has "blaze-doctor" on.scripts) true;
    doctorReportsVersion = assay.eq (builtins.match ".*blaze --version.*" on.scriptExec.blaze-doctor != null) true;

    # The daemon is shared across checkouts, so killing it on shell exit is
    # opt-in, never the default.
    keepsDaemonByDefault = assay.eq on.enterShell "";
    stopOnExitTraps = assay.eq (builtins.match ".*blaze stop.*" stopOnExit.enterShell != null) true;
  }

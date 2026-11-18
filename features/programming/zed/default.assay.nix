# Colocated suite for features/programming/zed
#
# lib.hasInfix rather than builtins.match, for the reason spelled out in the helix
# suite: Nix's regex engine rejects `\[` and `\{`, which rules out matching most
# of what is worth asserting here.
let
  assay = import ./../../../common/assay/default.nix;
  lib = (import <nixpkgs> {}).lib;
  src = builtins.readFile ./default.nix;
  hasText = needle: lib.hasInfix needle src;
  mod = import ./default.nix {
    settings = {
      username = "tom";
      userdir = "/home/tom";
    };
    pkgs = {
      # Stubbed to return the rendered text, so the settings JSON this feature
      # will actually install can be parsed back rather than re-asserting the Nix
      # attrset that produced it.
      writeText = _: text: text;
      zed-editor = "zed-editor";
      nixd = "/nixd";
      alejandra = "/alejandra";
      taplo = "/taplo";
      ruff = "/ruff";
      nodejs_22 = "/nodejs";
    };
  };
  packages = mod.environment.systemPackages;
  activation = mod.system.activationScripts.zedSettingsSeed.text;
  activationHas = needle: lib.hasInfix needle activation;
in
  assay.suite "zed" {
    installsZed = assay.eq (builtins.elem "zed-editor" packages) true;

    # Same RAM claim as features/programming/helix, for the same measured reason:
    # a lighter editor that spawns rust-analyzer per project is not lighter.
    doesNotInstallRustAnalyzer = assay.eq (builtins.elem "rust-analyzer" packages) false;
    disablesRustLanguageServer = assay.eq (hasText "enable_language_server = false;") true;
    documentsTheRamReason = assay.eq (hasText "4.8 GB") true;

    # Zed downloads language servers and its own Node by default; on NixOS those
    # are generic glibc binaries that hit stub-ld and never come up. Both must be
    # pinned into the store, and the servers installed so those paths resolve.
    pinsNodePath = assay.eq (hasText "npm_path = npmBin;") true;
    pinsLspBinaries = assay.eq (hasText "nixd.binary.path = nixdBin;") true;
    documentsStubLd = assay.eq (hasText "stub-ld") true;

    # These four are the ones that caught the shadowing bug: `let nixd = ...`
    # outranks the `with pkgs` scope in systemPackages, so the first version of
    # this feature installed bare path strings instead of derivations. Comparing
    # against the stub *packages* rather than the *Bin paths is what makes the
    # difference visible.
    installsNixd = assay.eq (builtins.elem "/nixd" packages) true;
    installsAlejandra = assay.eq (builtins.elem "/alejandra" packages) true;
    installsTaplo = assay.eq (builtins.elem "/taplo" packages) true;
    installsRuff = assay.eq (builtins.elem "/ruff" packages) true;
    installsNode = assay.eq (builtins.elem "/nodejs" packages) true;
    installsNoBarePathStrings =
      assay.eq
      (builtins.any (p: lib.hasInfix "/bin/" p) packages)
      false;

    # "direct", not "shell_hook": the hook option supports POSIX shells and fish,
    # and this fleet's login shell is nushell. Zed's own migration guide recommends
    # the wrong one for us, so pin both the choice and the reason.
    usesDirectDirenv = assay.eq (hasText "load_direnv = \"direct\";") true;
    doesNotUseShellHook = assay.eq (hasText "load_direnv = \"shell_hook\";") false;
    documentsNushellReason = assay.eq (hasText "nushell") true;

    telemetryOff = assay.eq (hasText "metrics = false;") true;

    # Zed 1.28.1 renamed features.edit_prediction_provider to
    # edit_predictions.provider and flags the old spelling with "Your settings
    # file uses deprecated settings". The first version of this feature shipped
    # the old key, so both halves are asserted: the new one present, the old one
    # gone. A seeded config makes this worth pinning — a wrong key here follows
    # the file into $HOME and is not fixed by the next deploy.
    # Asserted against the RENDERED JSON, not the source text: the writeText stub
    # puts the real settings document into the activation script, and the source
    # comment legitimately names the old key while explaining the rename. A
    # substring check on the source would therefore false-fail — the same trap the
    # cloudcli suite hit matching on paths its comments mention.
    rendersCurrentEditPredictionKey =
      assay.eq (activationHas ''"edit_predictions":{"provider":"none"}'') true;
    rendersNoDeprecatedFeaturesKey = assay.eq (activationHas ''"features"'') false;

    # relative_line_numbers is a boolean in 1.28.1 even though the docs on `main`
    # describe a string enum. Pinned so a docs-led "fix" has to argue with the
    # binary's own "Expected relative_line_numbers to be a boolean" first.
    relativeLineNumbersIsBoolean = assay.eq (hasText "relative_line_numbers = true;") true;

    # Seeded, not symlinked: Zed's settings UI writes this file back, and a store
    # symlink would make saving fail. The inverse of the helix feature, on purpose,
    # so these three claims are what stop someone "harmonising" the two later.
    seedsSettingsPath = assay.eq (activationHas "/home/tom/.config/zed/settings.json") true;
    seedsOnlyWhenAbsent = assay.eq (activationHas "if [ ! -e ") true;
    doesNotSymlinkSettings = assay.eq (activationHas "ln -sfn") false;
    documentsWhySeeded = assay.eq (hasText "settings UI writes settings.json back to") true;
  }

# Colocated suite: generated Nushell vendor autoload.
#
# This module is option-gated, so the suite exercises both states. The facts worth pinning are
# the ones a later wave can break without noticing: the activation-script name other features
# and docs refer to, the hook filenames whose numeric prefix IS the load order, that each
# hook's content comes from the installed binary's own `init` rather than a committed copy, and
# that the relocated environment.sessionVariables survive the gate being turned off.
#
# The module is evaluated against the real NixOS option tree. The autoload directory reaches
# config only as the store path the activation script links, so its build script is read back
# out of the .drv the evaluator wrote — the generated script is the artifact under test.
let
  assay = import ./../../../common/assay/default.nix;
  nixos = import ./../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  eval = shellInit:
    nixos.eval {
      modules = [./default.nix {cli.shellInit = shellInit;}];
      settings = {
        username = "alice";
        userdir = "/home/alice";
      };
      # The real value is a store path from the `nu-scripts` flake input. A literal stands in
      # so the completer paths this module builds are readable in assertions.
      inputs.nu-scripts = "/nu-scripts";
    };

  enabled = eval {};
  disabled = eval {enable = false;};
  trimmed = eval {hooks = ["env" "starship"];};

  # The `attr` of the derivation named `name` that `str` refers to, read from its .drv.
  unescape = builtins.replaceStrings ["\\\\" "\\\"" "\\n" "\\r" "\\t"] ["\\" "\"" "\n" "\r" "\t"];
  envOf = aterm: name:
    unescape (builtins.head (lib.splitString "\")])" (builtins.head (lib.splitString "\"),(\""
            (builtins.elemAt (lib.splitString "(\"${name}\",\"" aterm) 1)))));
  drvAttr = name: str: attr: let
    drvPath =
      builtins.head (builtins.filter (lib.hasSuffix "-${name}.drv")
        (builtins.attrNames (builtins.getContext str)));
    # The values are compared as text; the store references they carry are not needed.
    aterm = builtins.unsafeDiscardStringContext (builtins.readFile drvPath);
  in
    if lib.hasInfix "(\"__json\",\"" aterm
    then (builtins.fromJSON (envOf aterm "__json")).${attr}
    else envOf aterm attr;

  activationOf = cfg: cfg.system.activationScripts.nushellVendorAutoload.text;
  activation = activationOf enabled;
  buildOf = cfg: drvAttr "nushell-vendor-autoload" (activationOf cfg) "buildCommand";
  build = buildOf enabled;
  # The build script's comments explain it; claims are about its commands.
  codeOf = text:
    lib.concatStringsSep "\n"
    (builtins.filter (l: !(lib.hasPrefix "#" (lib.trim l))) (lib.splitString "\n" text));
  buildCode = codeOf build;

  has = haystack: needle: lib.hasInfix needle haystack;
  # Every file the build writes into $out (by `cp` or by redirecting an init), in the order it
  # writes them.
  writtenFiles = text:
    lib.concatMap (l: let
      m = builtins.match " *(cp [^ ]+|.* >) \\$out/([0-9][0-9]-[a-z-]+\\.nu)" l;
    in
      if m == null
      then []
      else [(builtins.elemAt m 1)])
    (lib.splitString "\n" (codeOf text));

  # Nushell sources the directory in filename order, so this list is the load order and the
  # concatenation below has to stay sorted.
  hookFiles = [
    "00-nixos-env.nu"
    "10-starship.nu"
    "20-zoxide.nu"
    "30-carapace.nu"
    "40-atuin.nu"
  ];

  # Prefixed alphabetically by tool rather than by the default set, so a host opting cargo or
  # docker in renumbers nothing.
  completerFiles = [
    "50-cargo-completions.nu"
    "51-docker-completions.nu"
    "52-git-completions.nu"
    "53-make-completions.nu"
    "54-nix-completions.nu"
  ];

  all = eval {completers = ["cargo" "docker" "git" "make" "nix"];};
  loadOrder = writtenFiles (buildOf all);
in
  assay.suite "shell-init" {
    # On by default: profiles/cli-core.nix imports this for every host, so the import is the
    # opt-in. features/fleet/keepalived is the opposite case and defaults to false.
    enabledByDefault = assay.eq enabled.cli.shellInit.enable true;
    disabledEmitsNoActivation =
      assay.eq (disabled.system.activationScripts ? nushellVendorAutoload) false;

    # The activation-script name is referred to by bin/update/system and by
    # features/cli/nushell's own comment. Renaming it is a documentation break.
    activationScriptName = assay.eq (enabled.system.activationScripts ? nushellVendorAutoload) true;

    # Nushell only looks in `$nu.data-dir/vendor/autoload`, which is the last and
    # highest-precedence entry of `$nu.vendor-autoload-dirs`. Any other path is dead weight.
    # One directory symlink, not a file-by-file copy: dropping a hook has to take its file with
    # it, or Nushell keeps sourcing a generator output nothing generates any more.
    linksWholeDirectoryIntoTheDataDir =
      assay.eq (builtins.match ".*ln -sfn /nix/store/[a-z0-9]+-nushell-vendor-autoload /home/alice/\\.local/share/nushell/vendor/autoload\n.*" activation != null) true;

    # Activation runs as root. Without this the user owns none of their own shell state.
    chownsToUser = assay.eq (has activation "chown -h alice:users /home/alice/.local/share/nushell/vendor/autoload") true;

    # Every hook and completer file, written in the order its numeric prefix fixes.
    hookFilenames = assay.eq (writtenFiles build) (hookFiles ++ ["52-git-completions.nu" "53-make-completions.nu" "54-nix-completions.nu"]);

    hooksDefaultToAll =
      assay.eq enabled.cli.shellInit.hooks ["env" "starship" "zoxide" "carapace" "atuin"];
    hooksAreSelectable = assay.eq trimmed.cli.shellInit.hooks ["env" "starship"];
    # Selecting hooks changes what is generated, not just the option value.
    trimmedHooksReachTheBuild =
      assay.eq (writtenFiles (buildOf trimmed)) ["00-nixos-env.nu" "10-starship.nu" "52-git-completions.nu" "53-make-completions.nu" "54-nix-completions.nu"];

    # ---- nu_scripts completers -------------------------------------------------------------

    # Every completer filename, with the 5x prefix that puts it behind the external completer.
    completerFilenames = assay.eq (builtins.filter (f: builtins.elem f completerFiles) loadOrder) completerFiles;

    # Filename order IS load order, and the whole directory has to sort into the sequence the
    # feature's comments claim. A completer renumbered in front of carapace would put the
    # largest, fastest-churning files in the directory ahead of the prompt, `cd` and history —
    # so a bad nu_scripts bump would break the shell rather than just its completions.
    loadOrderIsSorted = assay.eq (builtins.sort (a: b: a < b) loadOrder) loadOrder;
    completersLoadLast = assay.eq loadOrder (hookFiles ++ completerFiles);

    # Consumed from the pinned flake input, never copied in. The committed-copy defect this
    # feature exists to end applies to upstream scripts exactly as it did to `starship init`.
    consumesTheFlakeInput =
      assay.eq (has build "cp /nu-scripts/custom-completions/git/git-completions.nu $out/52-git-completions.nu") true;
    vendorsNoNuFiles =
      assay.eq
      (builtins.filter (n: lib.hasSuffix ".nu" n) (builtins.attrNames (builtins.readDir ./.)))
      [];

    # nu_scripts is written against whatever Nushell release upstream had, and autoload files
    # only ever run on the interactive path — so a completer that no longer parses prints its
    # error on every shell start and in no test. nu-check at build time is the only place that
    # failure can be made visible before it reaches a prompt.
    parseCheckedAtBuildTime =
      assay.eq (has buildCode "--commands \"exit (if (nu-check '$f') { 0 } else { 1 })\"; then") true;
    parseFailureFailsTheBuild =
      assay.eq (builtins.match ".*does not parse under nushell [^\n]*\n *exit 1\n.*" buildCode != null) true;

    # Budget, not taste: all five completers are +8.6 ms of interactive startup against a
    # 35 ms ceiling, and these three are +5.8 ms. cargo and docker stay reachable.
    completersDefaultToTheBudgetSafeSet =
      assay.eq enabled.cli.shellInit.completers ["git" "make" "nix"];
    completersAreSelectable =
      assay.eq all.cli.shellInit.completers ["cargo" "docker" "git" "make" "nix"];

    # The option has to reach the derivation, not just the option tree. Changing the set
    # changes the build, so it changes the store path the activation script links.
    completersReachTheDerivation =
      assay.eq (activation == activationOf (eval {completers = [];})) false;

    # The point of the whole feature: content comes from the installed binary's own `init`, so
    # it cannot drift from the binary. A committed copy of this output is the defect
    # features/cli/nushell/starship.nu was.
    runsStarshipInit =
      assay.eq (builtins.match ".*/nix/store/[a-z0-9]+-starship-[^/]+/bin/starship init nu > \\$out/10-starship\\.nu.*" build != null) true;
    runsZoxideInit =
      assay.eq (builtins.match ".*/nix/store/[a-z0-9]+-zoxide-[^/]+/bin/zoxide init nushell --cmd cd > \\$out/20-zoxide\\.nu.*" build != null) true;
    runsCarapaceInit =
      assay.eq (builtins.match ".*/nix/store/[a-z0-9]+-carapace-[^/]+/bin/carapace _carapace nushell > \\$out/30-carapace\\.nu.*" build != null) true;
    runsAtuinInit =
      assay.eq (builtins.match ".*/nix/store/[a-z0-9]+-atuin-[^/]+/bin/atuin init nu [^>]*> \\$out/40-atuin\\.nu.*" build != null) true;

    # Up recalls the previous line. atuin's init binds the bare Up key to its own search UI
    # unless told not to, and that binding lands in the generated file, after config.nu, so
    # nothing in config.nu can take it back.
    atuinDoesNotTakeTheUpArrow =
      assay.eq (builtins.match ".*/bin/atuin init nu --disable-up-arrow > .*" build != null) true;

    # Generated at build time, so a renamed subcommand fails the build rather than the prompt:
    # every generated hook file is checked non-empty.
    emptyInitFailsTheBuild =
      assay.eq (map (f: has buildCode "test -s $out/${f}") ["10-starship.nu" "20-zoxide.nu" "30-carapace.nu" "40-atuin.nu"])
      [true true true true];

    # carapace bakes $HOME/.config/carapace/bin into the PATH line it emits, so it is the one
    # hook that must run under the real home. Under the scratch HOME the generated file
    # prepended the build sandbox's /build/.config/carapace/bin to every shell's PATH.
    carapaceRunsUnderRealHome =
      assay.eq (builtins.match ".*\nHOME=/home/alice /nix/store/[^ ]+/bin/carapace _carapace nushell .*" build != null) true;
    otherHooksRunUnderScratchHome =
      assay.eq (map (t: builtins.match ".*\nHOME=\\$scratch /nix/store/[^ ]+/bin/${t} .*" build != null) ["starship" "zoxide" "atuin"])
      [true true true];

    # And the generic guard, because carapace will not be the last tool to do this.
    buildFailsOnSandboxLeak =
      assay.eq (builtins.match ".*if grep -rl -- \"\\$TMPDIR\" \\$out; then\n[^\n]*leaked the build sandbox path[^\n]*\n *exit 1\n.*" buildCode != null) true;

    # Relocated here from features/cli/fish, which had no claim on a global attribute. Declared
    # outside the enable gate: these are the host's variables, not this generator's.
    ownsSessionVariables = assay.subset enabled.environment.sessionVariables {
      EDITOR = "nvim";
      GIT_EDITOR = "nvim";
      DIFFPROG = "nvim -d";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
    };
    sessionVariablesSurviveDisable = assay.eq disabled.environment.sessionVariables.EDITOR "nvim";
  }

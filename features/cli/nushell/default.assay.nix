# Colocated suite: nushell on systemPackages, login shell, and config activation.
let
  assay = import ./../../../common/assay/default.nix;
  lib = (import <nixpkgs> {}).lib;
  src = builtins.readFile ./default.nix;
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
      userdir = "/home/alice";
    };
    pkgs = {
      nushell = "nushell";
      callPackage = path: args: "havamal";
    };
  };
  activation = mod.system.activationScripts.linkNushellConfig.text;
  has = needle: builtins.match ".*${lib.escapeRegex needle}.*" activation != null;

  # Every .nu this feature still ships. starship.nu and login.nu are deliberately absent.
  nuFiles =
    builtins.attrNames
    (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nu" name)
      (builtins.readDir ./.));

  # config.nu carries the interactive surface, and Nix cannot run a shell to observe it.
  # These claims read it as text, the way `envDoesNotSourceStarship` below already does:
  # enough to catch a setting deleted, re-hand-written, or silently unbounded again.
  config = builtins.readFile ./config.nu;
  inConfig = needle: lib.hasInfix needle config;
  fdCallSites = builtins.filter (lib.hasInfix "fd --type") (lib.splitString "\n" config);
in
  assay.suite "nushell" {
    packages = assay.eq mod.environment.systemPackages ["nushell"];
    shells = assay.eq mod.environment.shells ["nushell"];
    loginShell = assay.eq mod.users.users.alice.shell "nushell";
    linksConfigOnActivate = assay.eq (builtins.match ".*linkNushellConfig.*" src != null) true;

    # The prompt and the NixOS session variables moved to features/cli/shell-init, which
    # generates them into $nu.data-dir/vendor/autoload from the installed binaries. Linking
    # them from here as well would give two writers for one prompt.
    linksOnlyHandWrittenConfig = assay.eq (has "for file in env.nu config.nu havamal.nu; do") true;

    # Earlier generations left these two as symlinks in ~/.config/nushell. Their sources are
    # gone, so activation has to clear the dangling links rather than leave litter.
    clearsStaleLinks = assay.eq (has "for stale in login.nu starship.nu; do") true;

    # No .nu file in this feature is a committed copy of a tool's `init` output: that copy
    # drifts from the binary it came from, which is why starship.nu was deleted.
    shipsNoGeneratorOutput = assay.eq nuFiles ["config.nu" "env.nu" "havamal.nu"];
    envDoesNotSourceStarship =
      assay.eq (lib.hasInfix "source starship.nu" (builtins.readFile ./env.nu)) false;

    # bin/update/system no longer calls a link script for this feature; activation is the
    # single writer. A reintroduced script would be a second, divergent one — the old one
    # never linked havamal-stanzas and never chowned, so running it left a half-linked
    # config directory. setup.sh was a back-compat wrapper around it and went with it.
    hasNoLinkScript = assay.eq (builtins.pathExists ./bin/link-files-nixos) false;
    hasNoSetupWrapper = assay.eq (builtins.pathExists ./setup.sh) false;

    # Completions: fuzzy matching with smart sorting, externals on. The completer itself is
    # carapace's — 30-carapace.nu assigns it from the installed binary after config.nu runs,
    # so a completer written here would be overwritten, which is why it must not appear.
    completionsAreFuzzy = assay.eq (inConfig ''completions.algorithm = "fuzzy"'') true;
    completionsSortIsSmart = assay.eq (inConfig ''completions.sort = "smart"'') true;
    externalCompletionsEnabled = assay.eq (inConfig "completions.external.enable = true") true;
    doesNotHandWriteTheCompleter = assay.eq (inConfig "external.completer") false;
    completionsKeepCaseInsensitivity = assay.eq (inConfig "completions.case_sensitive = false") true;
    completionsStayQuickAndPartial =
      assay.eq [(inConfig "completions.quick = true") (inConfig "completions.partial = true")] [true true];

    # Every fd call site carries a depth bound. Unbounded with --hidden, the fzf bindings
    # walked 223k directories / 1.7M files from $HOME — a multi-second freeze per keypress —
    # and there is exactly one call site so that the bound cannot be forgotten at a new one.
    fdIsCalledFromOnePlace = assay.eq (builtins.length fdCallSites) 1;
    everyFdCallSiteIsBounded =
      assay.eq (builtins.all (lib.hasInfix "--max-depth") fdCallSites) true;
    fdPrunesTheHeavyCaches = assay.eq (builtins.all (dir: inConfig "--exclude ${dir}")
      [".cache" ".cargo" ".npm" ".bun" ".rustup" "node_modules" ".direnv" ".devenv"])
    true;

    # FZF_DEFAULT_OPTS (features/cli/fzf) owns height, layout, border and preview. A binding
    # that restates them is the drift that ends with two different fzf looks in one shell.
    fzfBindingsDoNotRestateLayout =
      assay.eq [(inConfig "--height") (inConfig "--reverse")] [false false];

    # The sessionizer: zoxide's frecency list plus a *bounded* scan of the project roots,
    # into fzf, into a session named after the directory, on one key.
    shipsASessionizer = assay.eq (inConfig "def --env sessionize") true;
    sessionizerUsesZoxideAndABoundedScan =
      assay.eq [(inConfig "zoxide query -l") (inConfig "fd-bounded d 2")] [true true];
    sessionizerAttachesByBasename =
      assay.eq (inConfig "zellij attach --create $name") true;
    sessionizerIsBoundToAKey = assay.eq (inConfig ''cmd: "sessionize"'') true;

    # Auto-attach. Every one of these guards is load-bearing: without the first, `nu -c` and
    # every agent and script that runs it ends up trapped inside a pane.
    autoAttachRequiresInteractive = assay.eq (inConfig "if not $interactive { return false }") true;
    autoAttachRefusesInsideAPane = assay.eq (inConfig "if ($env.ZELLIJ? != null) { return false }") true;
    autoAttachRequiresTerminalOrSsh =
      assay.eq [(inConfig "$env.SSH_TTY?") (inConfig "^tty --silent")] [true true];
    autoAttachHasAnOptOut = assay.eq (inConfig "ZELLIJ_AUTO_ATTACH") true;

    # Hávamál stays. It costs ~3 ms and it is the one piece of this shell that is not
    # utility; HAVAMAL=0 and the in-pane check are what keep it from being a nuisance.
    havamalStillPrints =
      assay.eq [(inConfig "source havamal.nu") (inConfig "havamal | print")] [true true];
    havamalHonoursItsEnvGuard = assay.eq (inConfig ''$env.HAVAMAL? | default "1"'') true;

    # Reedline: the IDE completion menu on tab, and the history hint acceptable whole or by
    # word.
    bindsTheIdeCompletionMenu =
      assay.eq [(inConfig "menu name: ide_completion_menu") (inConfig "keycode: tab")] [true true];
    bindsHistoryHintAcceptance =
      assay.eq [(inConfig "historyhintcomplete") (inConfig "historyhintwordcomplete")] [true true];

    # Dead weight wave 4 made of this file, now removed. Ctrl-R belongs to atuin
    # (40-atuin.nu registers it after config.nu), `cd` to zoxide (20-zoxide.nu), and the
    # vi-mode prompt glyph to starship's `character` module.
    leavesCtrlRToAtuin = assay.eq (inConfig "char_r") false;
    leavesCdToZoxide = assay.eq (inConfig "alias cd") false;
    leavesTheViIndicatorToStarship = assay.eq (inConfig "PROMPT_INDICATOR") false;
    configDoesNotSourceStarship = assay.eq (inConfig "source starship.nu") false;

    # `c` is cd-and-list, and a plain `def` would scope the cd to the body and leave the
    # caller where it started — the command has never actually worked without --env.
    cChangesTheCallersDirectory = assay.eq (inConfig "def --env c [") true;
  }

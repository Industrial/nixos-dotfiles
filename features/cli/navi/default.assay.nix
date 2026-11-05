# Colocated suite: navi as the owner of this fleet's own cheatsheets.
#
# A .cheat file with a syntax error is not an error — navi parses what it understands and
# silently drops the rest — so the cheap structural facts are worth asserting here rather than
# discovering interactively: every sheet opens with a `%` tag line, and every snippet has a
# comment above it, because navi's `write_cmd` throws away an item whose comment is empty.
#
# The rest of the suite pins the wiring: that the sheets land where navi looks by default, that
# the parent directory stays writable, and that `--tldr` is told it is talking to tealdeer.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = import <nixpkgs> {};
  nixpkgsLib = pkgs.lib;

  configYaml = builtins.readFile ./config.yaml;

  # No options, so no evalModules: the module is a plain function of pkgs and settings.
  mod = import ./default.nix {
    inherit pkgs;
    settings = {
      hostname = "h";
      username = "alice";
      userdir = "/home/alice";
    };
  };

  activation = mod.system.activationScripts.linkNaviCheats.text;

  has = haystack: needle: nixpkgsLib.hasInfix needle haystack;

  # ---------------------------------------------------------------------------
  # The sheets themselves
  # ---------------------------------------------------------------------------
  # builtins.attrNames returns its keys sorted, so the expected list below is stable.
  sheetNames = builtins.attrNames (builtins.readDir ./cheats);

  sheetLines = name: nixpkgsLib.splitString "\n" (builtins.readFile (./cheats + "/${name}"));

  # navi's parser dispatches on the first character of each line: `%` tags, `@` dependency,
  # `;` metacomment, `#` comment, `$` variable, anything else is snippet text
  # (navi-2.24.0 src/parser.rs).
  firstTagLine = name:
    builtins.head (builtins.filter (l: nixpkgsLib.hasPrefix "%" l) (sheetLines name));

  snippetLines = name:
    builtins.filter
    (l:
      l
      != ""
      && !(builtins.any (p: nixpkgsLib.hasPrefix p l) ["%" "#" "$" ";" "@"]))
    (sheetLines name);

  # A snippet is only reachable if a `# comment` line precedes it, because navi drops an item
  # whose comment is empty. Walk each file and collect the snippet lines that have no comment
  # anywhere above them in the current item.
  orphanSnippets = name:
    (builtins.foldl'
      (acc: line:
        if nixpkgsLib.hasPrefix "#" line
        then acc // {commented = true;}
        else if nixpkgsLib.hasPrefix "%" line || nixpkgsLib.hasPrefix "$" line
        then acc // {commented = false;}
        else if line == "" || nixpkgsLib.hasPrefix ";" line || nixpkgsLib.hasPrefix "@" line
        then acc
        else if acc.commented
        then acc
        else acc // {orphans = acc.orphans ++ [line];})
      {
        commented = false;
        orphans = [];
      }
      (sheetLines name))
    .orphans;

  allSheets = builtins.concatStringsSep "\n" (map (n: builtins.readFile (./cheats + "/${n}")) sheetNames);
in
  assay.suite "navi" {
    systemPackages = assay.eq (map nixpkgsLib.getName mod.environment.systemPackages) ["navi"];

    # ---------------------------------------------------------------------------
    # The sheets parse
    # ---------------------------------------------------------------------------
    sheetsArePresent = assay.eq sheetNames [
      "fleet.cheat"
      "gates.cheat"
      "help.cheat"
      "nix-eval.cheat"
      "rebuild.cheat"
      "security.cheat"
      "zellij.cheat"
    ];
    # navi only picks up *.cheat and *.cheat.md (`all_cheat_files`), so a stray README in here
    # would be ignored rather than rejected — and an entry in a file navi ignores is an entry
    # nobody will ever see.
    everySheetIsACheatFile =
      assay.eq (builtins.all (n: nixpkgsLib.hasSuffix ".cheat" n) sheetNames) true;

    # Tags are what `--tag-rules dotfiles` filters on, and an untagged item lands under the
    # empty tag where no filter reaches it.
    everySheetOpensWithATag = assay.eq (map firstTagLine sheetNames) [
      "% dotfiles, fleet, deploy"
      "% dotfiles, gates, assay, ci"
      "% dotfiles, help, tldr, navi"
      "% dotfiles, nix, eval"
      "% dotfiles, rebuild"
      "% dotfiles, security, stig"
      "% dotfiles, zellij"
    ];
    # `without_prefix` is `line[2..]`, so `%tag` loses a character and `# comment` without the
    # space does too. Every tag and comment line needs the space.
    everyTagLineHasItsSpace =
      assay.eq (builtins.all (n: nixpkgsLib.hasPrefix "% " (firstTagLine n)) sheetNames) true;

    # The one that actually bites: a snippet with no comment above it is parsed, stored, and
    # then thrown away by `write_cmd`. Silently.
    noSnippetIsOrphaned = assay.eq (nixpkgsLib.concatMap orphanSnippets sheetNames) [];
    # And there is something to show in the first place.
    sheetsCarrySnippets =
      assay.eq (builtins.all (n: builtins.length (snippetLines n) >= 8) sheetNames) true;

    # ---------------------------------------------------------------------------
    # Where the sheets go
    # ---------------------------------------------------------------------------
    activationScriptName = assay.eq (mod.system.activationScripts ? linkNaviCheats) true;
    doesNotClaimGenericLinkFile = assay.eq (mod.system.activationScripts ? linkFile) false;
    # $XDG_DATA_HOME/navi/cheats is navi's own `default_cheat_pathbuf()`: land there and no
    # configuration is needed to find the sheets at all.
    linksIntoNavisDefaultCheatPath =
      assay.eq (has activation "/home/alice/.local/share/navi/cheats/dotfiles") true;
    # A subdirectory, not the directory itself: `navi repo add` writes into the parent and a
    # sheet written by hand belongs beside ours, so the parent stays a real writable directory.
    cheatsParentStaysWritable =
      assay.eq (has activation "install -d -o alice -g users -m 0755 /home/alice/.local/share/navi/cheats") true;
    # -h, or chown follows the link and tries to chown the store.
    chownsTheLinkNotItsTarget =
      assay.eq (has activation "chown -h alice:users") true;

    linksConfigIntoPlace = assay.eq (has activation "/home/alice/.config/navi/config.yaml") true;
    keepsAPreExistingRealConfig = assay.eq (has activation "config.yaml.backup") true;

    # ---------------------------------------------------------------------------
    # The config
    # ---------------------------------------------------------------------------
    #
    # navi's --tldr client shells out to whatever `tldr` is on PATH and picks its output flag
    # from this boolean alone: true is `--raw` (tealdeer's), false is `--markdown` (the
    # node client's, which tealdeer rejects). features/cli/tealdeer is what provides `tldr`.
    tldrClientIsTealdeer = assay.eq (has configYaml "tealdeer: true") true;
    finderIsFzf = assay.eq (has configYaml "command: fzf") true;
    # Naming the store path here would make this repo's sheets the only ones navi can see, and
    # the activation link already puts them where navi looks.
    namesNoCheatPaths = assay.eq (has configYaml "paths:") false;

    # ---------------------------------------------------------------------------
    # Content, not generic Linux
    # ---------------------------------------------------------------------------
    #
    # The point of the feature. tldr already knows about tar; only this repo knows these.
    coversTheHostEvalIdiom =
      assay.eq (has allSheets "nix eval --raw \".#nixosConfigurations.<host>.config.system.build.toplevel.drvPath\"") true;
    coversFleetDeploy = assay.eq (has allSheets "bin/fleet deploy <host> --dry-activate") true;
    coversAssay = assay.eq (has allSheets "devenv shell -- assay run <path>") true;
    coversCoverageCheck = assay.eq (has allSheets "./bin/assay-coverage-check") true;
    coversStigVmTests = assay.eq (has allSheets "STIG_VM=1 bin/ci/stig") true;
    coversTheRebuildWrapper = assay.eq (has allSheets "bin/update/system") true;
    coversMoonTest = assay.eq (has allSheets "moon run dotfiles:test") true;
    # The zellij keymap is read from the live config rather than transcribed: config.kdl is
    # `clear-defaults=true` and is rewritten often enough that a copied table would be a lie.
    readsTheZellijKeymapRatherThanCopyingIt =
      assay.eq (has allSheets "bat ~/.config/zellij/config.kdl") true;
    transcribesNoZellijKeybinding = assay.eq (has allSheets "SwitchToMode") false;
  }

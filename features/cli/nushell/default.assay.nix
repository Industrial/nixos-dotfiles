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
  }

# Colocated suite: nushell on systemPackages, login shell, and config activation.
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
      userdir = "/home/alice";
    };
    pkgs = {nushell = "nushell";};
  };
in
  assay.suite "nushell" {
    packages = assay.eq mod.environment.systemPackages ["nushell"];
    shells = assay.eq mod.environment.shells ["nushell"];
    loginShell = assay.eq mod.users.users.alice.shell "nushell";
    linksConfigOnActivate = assay.eq (builtins.match ".*linkNushellConfig.*" src != null) true;
  }

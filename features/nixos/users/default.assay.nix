# Colocated suite: primary user from settings.
let
  assay = import ./../../../common/assay/default.nix;
  # Provide lib stub with mkForce function that just returns the value
  lib = {
    mkForce = x: x;
  };
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
    };
    inherit lib;
  };
in
  assay.suite "users" {
    username = assay.eq mod.users.users.alice.isNormalUser true;
  }

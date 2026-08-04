# Colocated suite: primary user from settings.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    settings = {
      hostname = "h";
      username = "alice";
    };
  };
in
  assay.suite "users" {
    username = assay.eq mod.users.users.alice.isNormalUser true;
  }

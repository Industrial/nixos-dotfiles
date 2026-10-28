# Colocated suite: V-268138 — no direct root login.
let
  assay = import ./../../../../common/assay/default.nix;
  fixture = import ./../lib/fixture.nix;
  mod = import ./V-268138.nix {};
in
  assay.suite "stig-V-268138" {
    mutableUsersOff = assay.eq mod.users.mutableUsers false;

    # nixpkgs defaults this to true, so the control is a real change — and the reason it
    # cannot be in base-safe: every password must be declared in Nix first.
    nixpkgsDefaultIsMutable = assay.eq (fixture.evalWith []).users.mutableUsers true;
  }

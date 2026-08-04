# Colocated suite: gnupg agent enable + packages.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
    pkgs = {
      gnupg = "gnupg";
      pinentry-all = "pinentry-all";
    };
  in
    import ./default.nix {inherit pkgs;};
in
  assay.suite "gpg" {
    packages = assay.eq mod.environment.systemPackages ["gnupg" "pinentry-all"];
    agent = assay.eq mod.programs.gnupg.agent.enable true;
  }

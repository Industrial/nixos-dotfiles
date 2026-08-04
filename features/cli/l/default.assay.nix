# Colocated suite: wrapper derivation name is installed.
let
  assay = import ./../../../common/assay/default.nix;
  mod = let
      pkgs = {
        stdenv = { mkDerivation = args: args.name; };
        eza = "eza";
        settings = {};
      };
      settings = { useremail = "a@b.c"; hostname = "h"; username = "u"; };
      mod = import ./default.nix { inherit pkgs; } // { };
      # some wrappers also take settings
      mod2 = builtins.tryEval (import ./default.nix { inherit pkgs settings; });
      mod' = if mod2.success then mod2.value else (import ./default.nix { inherit pkgs; });
    in mod'.environment.systemPackages;

in
  assay.suite "l" {
    systemPackages = assay.eq mod [ "l" ];
  }

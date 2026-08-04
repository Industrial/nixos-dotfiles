# Colocated suite: wrapper derivation name is installed.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  packages = ''
(    let
      pkgs = {
        stdenv = { mkDerivation = args: args.name; };
        eza = "eza";
        settings = {};
      };
      settings = { useremail = "a@b.c"; hostname = "h"; username = "u"; };
      mod = import ${modFile} { inherit pkgs; } // { };
      # some wrappers also take settings
      mod2 = builtins.tryEval (import ${modFile} { inherit pkgs settings; });
      mod' = if mod2.success then mod2.value else (import ${modFile} { inherit pkgs; });
    in mod'.environment.systemPackages)
'';
in
  assay.suite "l" {
    systemPackages = assay.eq packages ''[ "l" ]'';
  }

{
  nixpkgs,
  path,
  excludes,
  ...
}: let
  excludesString = builtins.concatStringsSep " " excludes;
in
  with import nixpkgs {system = "x86_64-linux";};
    stdenv.mkDerivation {
      name = "alejandra-check";
      dontBuild = true;
      src = path;
      doCheck = true;
      nativeBuildInputs = with nixpkgs; [alejandra];
      checkPhase = ''
        alejandra -c -e ${excludesString} .
      '';
      installPhase = ''
        mkdir "$out"
      '';
    }

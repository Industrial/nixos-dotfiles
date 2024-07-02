{
  # excludes,
  path,
  pkgs,
  ...
}: let
  # excludesString = builtins.concatStringsSep " " excludes;
in
  pkgs.stdenv.mkDerivation {
    name = "alejandra-check";
    dontBuild = true;
    src = path;
    doCheck = true;
    nativeBuildInputs = with pkgs; [alejandra];
    # checkPhase = ''
    #   alejandra -c -e ${excludesString} .
    # '';
    checkPhase = ''
      alejandra .
    '';
    installPhase = ''
      mkdir "$out"
    '';
  }

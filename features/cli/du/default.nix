{pkgs, ...}: let
  du = pkgs.stdenv.mkDerivation {
    name = "du";
    version = "1.0";
    src = ./.;
    buildInputs = [pkgs.dust];
    installPhase = ''
      mkdir -p $out/bin
      echo '#!/usr/bin/env bash' > $out/bin/du
      echo '${pkgs.dust} "$@"' >> $out/bin/du
      chmod +x $out/bin/du
    '';
  };
in {
  environment.systemPackages = [
    du
  ];
}

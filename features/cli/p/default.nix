{pkgs, ...}: let
  p = pkgs.stdenv.mkDerivation {
    name = "p";
    version = "1.0";
    src = ./.;
    installPhase = ''
      mkdir -p $out/bin
      echo '#!/usr/bin/env bash' > $out/bin/g
      echo 'pnpm "$@"' >> $out/bin/g
      chmod +x $out/bin/g
    '';
  };
in {
  environment.systemPackages = [
    p
  ];
}

{pkgs, ...}: let
  p = pkgs.stdenv.mkDerivation {
    name = "p";
    version = "1.0";
    src = ./.;
    installPhase = ''
      mkdir -p $out/bin
      echo '#!/usr/bin/env bash' > $out/bin/p
      echo 'pnpm "$@"' >> $out/bin/p
      chmod +x $out/bin/p
    '';
  };
in {
  environment.systemPackages = [
    p
  ];
}

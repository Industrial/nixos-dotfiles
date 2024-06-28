{
  pkgs,
  ...
}: let
  g = pkgs.stdenv.mkDerivation {
    name = "g";
    version = "1.0";
    src = ./.;
    installPhase = ''
      mkdir -p $out/bin
      echo '#!/usr/bin/env bash' > $out/bin/g
      echo 'git "$@"' >> $out/bin/g
      chmod +x $out/bin/g
    '';
  };
in {
  environment.systemPackages = [
    g
  ];
}

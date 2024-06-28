{
  pkgs,
  ...
}: let
  c = pkgs.stdenv.mkDerivation {
    name = "c";
    version = "1.0";
    src = ./.;
    installPhase = ''
      mkdir -p $out/bin
      echo '#!/usr/bin/env bash' > $out/bin/c
      echo 'cd "$@" && l' >> $out/bin/c
      chmod +x $out/bin/c
    '';
  };
in {
  environment.systemPackages = [
    c
  ];
}

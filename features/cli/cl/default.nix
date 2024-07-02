{pkgs, ...}: let
  cl = pkgs.stdenv.mkDerivation {
    name = "cl";
    version = "1.0";
    src = ./.;
    installPhase = ''
      mkdir -p $out/bin
      echo '#!/usr/bin/env bash' > $out/bin/cl
      echo 'clear' >> $out/bin/cl
      chmod +x $out/bin/cl
    '';
  };
in {
  environment.systemPackages = [
    cl
  ];
}

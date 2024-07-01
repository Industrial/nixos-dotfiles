{pkgs, ...}: let
  l = pkgs.stdenv.mkDerivation {
    name = "l";
    version = "1.0";
    src = ./.;
    buildInputs = [
      pkgs.eza
    ];
    installPhase = ''
      mkdir -p $out/bin
      echo '#!/usr/bin/env bash' > $out/bin/l
      echo 'eza --colour=always --icons --long --group --header --time-style long-iso --git --classify --group-directories-first --sort Extension --all "$@"' >> $out/bin/l
      chmod +x $out/bin/l
    '';
  };
in {
  environment.systemPackages = [
    l
  ];
}

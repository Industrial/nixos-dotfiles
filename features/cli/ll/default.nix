{
  pkgs,
  ...
}: let
  ll = pkgs.stdenv.mkDerivation {
    name = "ll";
    version = "1.0";
    src = ./.;
    buildInputs = [ pkgs.eza ];
    installPhase = ''
      mkdir -p $out/bin
      echo '#!/usr/bin/env bash' > $out/bin/ll
      echo '${pkgs.eza} --colour=always --icons --long --group --header --time-style long-iso --git --classify --group-directories-first --sort Extension "$@"' >> $out/bin/ll
      chmod +x $out/bin/ll
    '';
  };
in {
  environment.systemPackages = [
    ll
  ];
}

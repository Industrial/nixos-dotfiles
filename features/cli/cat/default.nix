{
  pkgs,
  ...
}: let
  cat = pkgs.stdenv.mkDerivation {
    name = "l";
    version = "1.0";
    src = ./.;
    buildInputs = [ pkgs.bat ];
    installPhase = ''
      mkdir -p $out/bin
      echo '#!/usr/bin/env bash' > $out/bin/cat
      echo '${pkgs.bat} "$@"' >> $out/bin/cat
      chmod +x $out/bin/cat
    '';
  };
in {
  environment.systemPackages = [
    cat
  ];
}

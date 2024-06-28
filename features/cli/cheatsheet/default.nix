{
  pkgs,
  ...
}: let
  cheatsheet = pkgs.stdenv.mkDerivation {
    name = "cheatsheet";
    version = "1.0";
    src = ./.;
    buildInputs = [ pkgs.dust ];
    installPhase = ''
      mkdir -p $out/bin
      echo '#!/usr/bin/env bash' > $out/bin/cheatsheet
      echo 'curl "https://cheat.sh/$@"' >> $out/bin/cheatsheet
      chmod +x $out/bin/cheatsheet
    '';
  };
in {
  environment.systemPackages = [
    cheatsheet
  ];
}

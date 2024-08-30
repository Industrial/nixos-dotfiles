{
  pkgs,
  settings,
  ...
}: let
  name = "create-ssh-key";
  package = pkgs.stdenv.mkDerivation {
    inherit name;
    version = "1.0";
    src = ./.;
    installPhase = ''
      mkdir -p $out/bin
      echo '#!/usr/bin/env bash' > $out/bin/${name}
      echo 'ssh-keygen -t ed25519-sk -O resident -O verify-required -C "${settings.useremail}"' >> $out/bin/${name}
      chmod +x $out/bin/${name}
    '';
  };
in {
  environment.systemPackages = [
    package
  ];
}

{pkgs, ...}: let
  cl = pkgs.rustPlatform.buildRustPackage {
    pname = "cl";
    version = "0.1.0";
    src = ../../../rust/tools/cl;

    cargoLock = {
      lockFile = ../../../rust/tools/cl/Cargo.lock;
      outputHashes = {
      };
    };

    meta = with pkgs.lib; {
      description = "A simple terminal clear command written in Rust";
      homepage = "https://github.com/yourusername/dotfiles";
      license = licenses.mit;
      maintainers = [];
    };
  };
in {
  environment.systemPackages = [
    cl
  ];
}

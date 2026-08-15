{ lib, pkgs, ... }:

let
  version = "0.1.1";
in
  pkgs.buildRustPackage rec {
    pname = "usbtree";
    version = version;

    src = pkgs.fetchFromGitHub {
      owner = "gnomeria";
      repo = "usbtree";
      rev = "v0.1.1";
      sha256 = "a315eeeb559911fffb1c2a17b6ebd418143168c888db5d3b737b05d8c34b3486";
    };

    meta = {
      description = "Live USB device tree in your terminal. Rust TUI, no root, no libusb. Full activity metrics on Linux; device tree on macOS/Windows.";
      homepage = "https://gnomeria.github.io/usbtree/";
      license = lib.licenses.mit;
      platforms = pkgs.platforms.linux;
      maintainers = [ pkgs.maintainers.unknown ];
    };
  }
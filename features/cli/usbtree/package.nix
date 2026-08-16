{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "usbtree";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "gnomeria";
    repo = "usbtree";
    rev = "v${version}";
    hash = "sha256-780SdrC2vaLQKJElabevYifBSv1WUOwjqYfbj7Fsm3E=";
  };

  cargoHash = "sha256-6uP2YuPeZVZa+AKOyki+hgvE28+yWkPvpt+QifFOxgo=";

  meta = {
    description = "Live USB device tree TUI (no root, no libusb)";
    homepage = "https://gnomeria.github.io/usbtree/";
    license = lib.licenses.mit;
    mainProgram = "usbtree";
    platforms = lib.platforms.linux;
  };
}

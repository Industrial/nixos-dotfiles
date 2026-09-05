# Skjold — Rust Hyprland panel built with Iced.
# Build with: nix-build -E 'with import <nixpkgs> {}; callPackage ./default.nix {}'
{
  lib,
  rustPlatform,
  pkg-config,
  patchelf,
  wayland,
  libxkbcommon,
  vulkan-loader,
  libGL,
}:
rustPlatform.buildRustPackage {
  pname = "skjold";
  version = "0.1.0";

  src = ../../.; # Workspace root (contains Cargo.lock)

  cargoLock = {
    lockFile = ../../Cargo.lock;
    outputHashes = {
      "nixdrv-0.1.0" = "sha256-qIKlfwaZwawwbVddBLsRglpD6LnpZwpTb1b6xcdRN3Q=";
    };
  };

  buildAndTestSubdir = "tools/skjold";

  nativeBuildInputs = [
    pkg-config
    patchelf
  ];

  buildInputs = [
    wayland
    libxkbcommon
    vulkan-loader
    libGL
  ];

  # Iced dlopen()s these at runtime for Wayland - must run after fixupPhase shrinks rpath
  postFixup = ''
    patchelf --add-rpath ${lib.makeLibraryPath [wayland libxkbcommon vulkan-loader libGL]} $out/bin/skjold
  '';

  meta = with lib; {
    description = "Hyprland panel shell built with Iced and Rust";
    license = licenses.mit;
    mainProgram = "skjold";
    platforms = platforms.linux;
  };
}

# Skjold — Rust Hyprland panel built with Iced.
# Build with: nix-build -E 'with import <nixpkgs> {}; callPackage ./default.nix {}'
{
  lib,
  rustPlatform,
  pkg-config,
  wayland,
  libxkbcommon,
  vulkan-loader,
  libGL,
}:
rustPlatform.buildRustPackage {
  pname = "skjold";
  version = "0.1.0";

  src = ../../.; # Workspace root (contains Cargo.lock)

  cargoLock.lockFile = ../../Cargo.lock;

  buildAndTestSubdir = "tools/skjold";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    wayland
    libxkbcommon
    vulkan-loader
    libGL
  ];

  # Iced needs these at runtime for Wayland
  postInstall = ''
    patchelf --add-rpath ${lib.makeLibraryPath [wayland libxkbcommon vulkan-loader libGL]} $out/bin/skjold
  '';

  meta = with lib; {
    description = "Hyprland panel shell built with Iced and Rust";
    license = licenses.mit;
    mainProgram = "skjold";
    platforms = platforms.linux;
  };
}

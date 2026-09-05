# Bifröst — NixOS fleet command center built with Iced.
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
  openssl,
}:
rustPlatform.buildRustPackage {
  pname = "bifrost";
  version = "0.1.0";
  src = ../../.;

  cargoLock = {
    lockFile = ../../Cargo.lock;
    outputHashes = {
      # Add hashes for git dependencies here if needed
    };
  };

  buildAndTestSubdir = "tools/bifrost";

  nativeBuildInputs = [pkg-config patchelf];
  buildInputs = [wayland libxkbcommon vulkan-loader libGL openssl];

  # Iced dlopen()s these at runtime for Wayland/Vulkan
  postFixup = ''
    patchelf --add-rpath ${lib.makeLibraryPath [wayland libxkbcommon vulkan-loader libGL]} $out/bin/bifrost
  '';

  meta = with lib; {
    description = "NixOS fleet command center";
    license = licenses.mit;
    mainProgram = "bifrost";
    platforms = platforms.linux;
  };
}

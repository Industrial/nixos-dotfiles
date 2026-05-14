# lean-ctx — Context Runtime for AI Agents — https://github.com/yvgude/lean-ctx
#
# 90+ compression patterns, 42 MCP tools, Context Continuity Protocol.
# Not in nixpkgs; built here from crates.io using buildRustPackage + fetchCrate.
#
# Version policy:
# - `version` matches the crate version published to crates.io.
# - `hash` is the SRI sha256 of the .crate tarball (from crates.io checksum, converted).
# - `cargoHash` is the vendored-deps hash; regenerate by setting lib.fakeHash and rebuilding.
#
# Issue #112 (feat: Hermes Support) — landed in v3.2.4:
#   https://github.com/yvgude/lean-ctx/issues/112
# Adds `lean-ctx init --agent hermes --global`, auto-detection of ~/.hermes/ in setup,
# Hermes MCP YAML writer, and doctor/uninstall support.
{
  lib,
  rustPlatform,
  fetchCrate,
}:
rustPlatform.buildRustPackage rec {
  pname = "lean-ctx";
  version = "3.5.25";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-BAdPDBgp3oqQYtsOzyb76DWjZzyHietxgKwnhXQl3m4=";
  };

  cargoHash = "sha256-2qiUkmt2+hWwzY6GdFl9jU5GfW2cGJ0UsbuitBcc7xg=";

  # Upstream tests assume a full dev shell (Python, sandbox tooling); skip in Nix sandbox.
  doCheck = false;

  meta = {
    description = "Context Runtime for AI Agents — shell compression + 42 MCP tools (lean-ctx v${version})";
    homepage = "https://github.com/yvgude/lean-ctx";
    changelog = "https://github.com/yvgude/lean-ctx/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = [];
    mainProgram = "lean-ctx";
    platforms = lib.platforms.unix;
  };
}

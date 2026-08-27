# Prebuilt Binary Packaging — NixOS Pattern

Sourced from dotfiles session 2026-05-26 (maestro fix).

## The Problem

NixOS cannot run dynamically linked executables intended for generic Linux
environments out of the box. The error:

```
Could not start dynamically linked executable: maestro
NixOS cannot run dynamically linked executables intended for generic
linux environments out of the box.
```

Most prebuilt release binaries from GitHub (e.g. `maestro-linux-x64`,
`sometool-linux-amd64`) are compiled against glibc and have a dynamic
linker path that points to `/lib64/ld-linux-x86-64.so.2` — a path that
exists on glibc Linux but is a stub on NixOS that refuses to execute
foreign binaries.

## The Fix

Patch **only** the ELF interpreter. Do **not** use `autoPatchelfHook` for
Bun-compiled standalone binaries (`bun build --compile`): it rewrites RPATH
and breaks the embedded `/$bunfs/` layout, so `my-tool --version` reports
`bun 1.x` instead of the app.

```nix
{
  lib,
  stdenv,
  fetchurl,
  patchelf,
}:
stdenv.mkDerivation rec {
  pname = "my-tool";
  version = "1.0.0";

  src = fetchurl {
    url = "https://github.com/owner/repo/releases/download/v${version}/my-tool-linux-x64";
    sha256 = "...";   # from nix-build --dry-run, then update after real build
  };

  dontUnpack = true;
  dontBuild = true;
  nativeBuildInputs = [ patchelf ];

  installPhase = ''
    install -D -m755 $src $out/bin/my-tool
    patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} $out/bin/my-tool
  '';

  meta = {
    description = "...";
    homepage = "...";
    license = lib.licenses.mit;
    mainProgram = "my-tool";
    platforms = lib.platforms.linux;
  };
}
```

## How to Update the Hash

1. Put `lib.fakeHash` (or any placeholder) as the sha256 value.
2. Run `nix-build -E 'with import <nixpkgs> {}; callPackage ./path/to/package.nix {}'` --dry-run.
   It will error and tell you the actual hash.
3. Copy the reported hash back into the file.
4. Build for real: `nix-build -E '...'`

## Updating a Package Version

When the upstream releases a new version:

1. Update `version`.
2. Update the `url` template — the version is typically embedded in the URL.
3. Replace `sha256` with `lib.fakeHash`.
4. Dry-run to get the new hash.
5. Plug the hash back in and build.

## Mixed Projects (CLI + MCP Server)

If the feature ships both a CLI binary AND an MCP server Python package,
the CLI binary goes in a `package.nix` with `stdenv.mkDerivation +
autoPatchelfHook`, and the Python MCP server goes in a sibling
`package-mcp.nix` with `python3Packages.buildPythonPackage`. The
`default.nix` wires both into `environment.systemPackages` via separate
`pkgs.callPackage` calls.
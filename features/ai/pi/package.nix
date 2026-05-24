# pi — Pi coding agent CLI — https://pi.dev
#
# Reverse-engineered from https://pi.dev/install.sh:
#   PI_PACKAGE="@earendil-works/pi-coding-agent"
#   npm install -g --ignore-scripts @earendil-works/pi-coding-agent
#
# Not in nixpkgs; built here from the published npm tarball using buildNpmPackage.
# The tarball ships pre-built dist/ and npm-shrinkwrap.json; we generate package-lock.json
# from the tarball (remove shrinkwrap first) with:
#   npm pack @earendil-works/pi-coding-agent@<version>
#   tar xzf *.tgz && cd package
#   rm -f npm-shrinkwrap.json
#   npm install --package-lock-only --ignore-scripts
# Then re-run: nix run nixpkgs#prefetch-npm-deps -- package-lock.json
#
# Invocation: pi
{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs,
  runCommand,
}: let
  version = "0.75.5";

  upstream = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-iP/3TR/MkzQ+g5qoherLNeiM2quX2sJjaxG+zDskmfw=";
  };

  # The published tarball ships npm-shrinkwrap.json without integrity hashes for
  # @earendil-works/* deps, which breaks nixpkgs' npm-deps prefetcher. Replace it
  # with a generated package-lock.json (see header comments).
  src = runCommand "pi-coding-agent-${version}-src" {} ''
    mkdir unpacked
    tar xzf ${upstream} -C unpacked
    cd unpacked/package
    rm -f npm-shrinkwrap.json
    cp ${./package-lock.json} package-lock.json
    cp -r . "$out"
  '';
in
  buildNpmPackage {
    pname = "pi-coding-agent";
    inherit version src;

    # Install script requires Node.js >= 22.19.0.
    inherit nodejs;

    npmDepsHash = "sha256-kQvdzRdDe5xAcxb1SJbGieWaZgM3AH+HIyKrc4yRAPA=";

    # Match upstream installer: skip lifecycle scripts; dist/ is pre-built in the tarball.
    npmInstallFlags = ["--ignore-scripts"];
    dontNpmBuild = true;

    meta = {
      description = "Minimal terminal coding harness (Pi coding agent CLI)";
      homepage = "https://pi.dev";
      changelog = "https://github.com/earendil-works/pi/releases";
      license = lib.licenses.mit;
      maintainers = [];
      mainProgram = "pi";
      platforms = lib.platforms.unix;
    };
  }

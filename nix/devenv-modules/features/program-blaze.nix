{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.local.features.program-blaze;

  # blaze (Indexable Inc) is a daemon-backed Rust build tool: `blaze build`,
  # `check`, `run`, `test` take cargo's flags and rebuild only what changed.
  # It ships its own toolchain — it never runs rustc, cargo, clippy or rustfmt,
  # and `rust-toolchain` files are not read.
  #
  # Installed from the pinned GitHub release, as program-moon and program-assay
  # are. The upstream flake builds blaze (and LLVM 23) from source with PGO,
  # which is hours of work per version bump for the same bytes.
  #
  # The release is NOT pinned in Cargo.toml: `[workspace.metadata.blaze] version`
  # makes blaze hand off to a release it downloads into `~/.blaze/versions`,
  # which would bypass this pin. This feature is the single pin.
  #
  # Pin the canary line, not `stable` (0.20261027.0), which cannot work here:
  # its bundled `gcc-ld/ld.lld` is a generic-linux dynamic executable NixOS
  # cannot exec (every link fails), `blaze test` fails to compile libtest's
  # `test_main_inner`, and it misreads `RUST_SRC_PATH` — which devenv's
  # `languages.rust` always sets — as the standard library's workspace.
  assets = {
    x86_64-linux = {
      triple = "x86_64-unknown-linux-gnu";
      hash = "sha256-QSH+6gaAnrXU1vT7W/5C/dSSge1zrc/fqjpdbGYcbOQ=";
    };
    aarch64-linux = {
      triple = "aarch64-unknown-linux-gnu";
      hash = "sha256-qn9xDWFIKHFjhTGsymPAV52JQcP6AkHtrei5/7XLODg=";
    };
    aarch64-darwin = {
      triple = "aarch64-apple-darwin";
      hash = "sha256-Y9rM2tOb7wLD4O8tbOaAAUqgPY4augvTS7iHdtQtHOA=";
    };
  };

  system = pkgs.stdenv.hostPlatform.system;
  asset =
    assets.${system}
    or (throw "local.features.program-blaze: blaze publishes no release for ${system} (x86_64-linux, aarch64-linux, aarch64-darwin only)");
  triple = asset.triple;
  hash =
    if cfg.releaseHash != null
    then cfg.releaseHash
    else asset.hash;

  blaze = pkgs.stdenv.mkDerivation {
    pname = "blaze";
    inherit (cfg) version;

    src = pkgs.fetchurl {
      url = "https://github.com/indexable-inc/blaze/releases/download/v${cfg.version}/blaze-v${cfg.version}-${triple}.tar.gz";
      inherit hash;
    };
    sourceRoot = "blaze-v${cfg.version}-${triple}";

    nativeBuildInputs = [pkgs.makeWrapper] ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [pkgs.autoPatchelfHook];
    buildInputs = [pkgs.stdenv.cc.cc.lib pkgs.zlib];

    # The release is built with PGO and ships stripped; stripping again only
    # risks breaking the shipped binaries.
    dontStrip = true;

    # `blaze` execs its siblings (blaze-engine, blaze-proc-macro-srv,
    # blaze-rustc) from its own realpath's directory, so they have to stay in
    # one directory together — hence libexec, with `bin` holding wrappers that
    # exec through to that directory rather than copies.
    #
    # blaze downloads its own toolchain to ~/.blaze/toolchains at run time; its
    # rust-lld needs libz.so.1, which NixOS has on no default path, so linking
    # the first build script fails with "libz.so.1: cannot open shared object
    # file". The wrapper hands this zlib (same glibc as the interpreter blaze
    # patches in) to the daemon and everything it starts.
    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/libexec/blaze $out/share/doc/blaze

      for f in blaze blaze-engine blaze-proc-macro-srv blaze-rustc; do
        if [ -f "$f" ]; then
          install -m755 "$f" "$out/libexec/blaze/$f"
          makeWrapper "$out/libexec/blaze/$f" "$out/bin/$f" \
            --prefix LD_LIBRARY_PATH : "${pkgs.zlib}/lib"
        fi
      done

      if [ ! -e $out/bin/blaze ]; then
        echo "program-blaze: the release tarball has no 'blaze' binary" >&2
        exit 1
      fi

      for f in README.md CHANGELOG.md LICENSE-MIT LICENSE-APACHE; do
        [ -f "$f" ] && install -m644 "$f" "$out/share/doc/blaze/$f"
      done

      runHook postInstall
    '';

    meta = {
      description = "blaze: cargo's build, check, run and test from a daemon that keeps the workspace compiled";
      homepage = "https://ix.dev/blaze";
      license = with lib.licenses; [mit asl20];
      platforms = builtins.attrNames assets;
      mainProgram = "blaze";
    };
  };
in {
  options.local.features.program-blaze = {
    enable = lib.mkEnableOption "blaze — the default Rust build/check/run/test command (pinned release)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "0.20261030.1";
      description = ''
        blaze release to pin, without the leading `v`. Overriding this also
        needs `releaseHash` — the per-system defaults only match the default
        version.
      '';
    };

    releaseHash = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        SRI hash of this system's release tarball. `null` uses the hash pinned
        for the default version; set it whenever `version` is overridden.
      '';
    };

    daemonStopOnExit = lib.mkEnableOption ''
      stop this user's blaze daemon when the shell exits. Off by default: the
      daemon is per user and shared by every checkout, and keeping it alive is
      what makes the next build fast
    '';
  };

  config = lib.mkIf cfg.enable {
    packages = [blaze];

    # One daemon per user holds the compiled workspace in memory; its budget is
    # the machine's memory less 1 GiB. `blaze status` prints what it holds.
    scripts.blaze-doctor.exec = ''
      set -euo pipefail
      echo "blaze:   $(blaze --version 2>&1 | tail -1)"
      echo "daemon:  $(blaze status 2>&1 | tr '\n' ' ' || echo 'not running')"
      echo "cache:   ''${BLAZE_HOME:-$HOME/.blaze} (toolchain, library, releases)"
    '';

    enterShell = lib.mkIf cfg.daemonStopOnExit (lib.mkAfter ''
      trap 'blaze stop >/dev/null 2>&1 || true' EXIT
    '');
  };
}

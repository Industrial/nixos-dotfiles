{
  inputs,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;

  moon = pkgs.stdenv.mkDerivation rec {
    pname = "moon-cli";
    version = "2.3.3";
    src = pkgs.fetchurl {
      url = "https://github.com/moonrepo/moon/releases/download/v2.3.3/moon_cli-x86_64-unknown-linux-gnu.tar.xz";
      sha256 = "19y47x4dh2dkvzx0nfzjcw97qvwiidkh0dimza6da4ivjdywfa66";
    };
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [pkgs.stdenv.cc.cc.lib];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 moon $out/bin/moon
      runHook postInstall
    '';
    meta = {
      description = "Moon CLI (moonrepo)";
      homepage = "https://moonrepo.dev";
      license = pkgs.lib.licenses.mit;
      platforms = pkgs.lib.platforms.linux;
    };
  };

  roam-code-src = pkgs.fetchFromGitHub {
    owner = "Cranot";
    repo = "roam-code";
    rev = "9023ed76922d61ae4514d15e9d81b86ddfaf1569";
    hash = "sha256-hE1gihZlJUQ8e8dOOpsxQM3b2KgvPAsU4wsJclmkptc=";
  };
  roam-code = pkgs.python3Packages.buildPythonApplication rec {
    pname = "roam-code";
    version = "11.2.0";
    src = roam-code-src;
    format = "pyproject";
    nativeBuildInputs = with pkgs.python3Packages; [setuptools wheel];
    propagatedBuildInputs = with pkgs.python3Packages; [
      click
      tree-sitter
      tree-sitter-language-pack
      networkx
      fastmcp
    ];
    doCheck = false;
  };

  # Assay workspace tools (github:Industrial/assay) + local nix-hash.
  pkgs-unstable = import inputs.nixpkgs-unstable {inherit system;};
  assayPkgs = inputs.assay.packages.${system};
  nixHash = pkgs.callPackage ./rust/tools/nix-hash {
    rustc = pkgs-unstable.rustc;
    cargo = pkgs-unstable.cargo;
  };


  lean-ctx = pkgs.rustPlatform.buildRustPackage rec {
    pname = "lean-ctx";
    version = "3.1.5";
    src = pkgs.fetchCrate {
      inherit pname version;
      hash = "sha256-WrLKCd6YzN5fxmBlyv9XSvAKXEtMbhuskyeDeLNFG2w=";
    };
    cargoHash = "sha256-n/xrYp8OLkmjbm3hjS9Mzx18VHs8Oh4Op767NM6rmI0=";
    doCheck = false;
  };
in {
  dotenv.enable = true;

  env = {
    RUST_BACKTRACE = "1";
    RUST_LOG = "debug";
    NIXPKGS_ALLOW_UNFREE = "1";
    LLVM_COV = "${pkgs.llvmPackages.llvm}/bin/llvm-cov";
    LLVM_PROFDATA = "${pkgs.llvmPackages.llvm}/bin/llvm-profdata";
  };

  packages = with pkgs; [
    inputs.definitively.packages.${system}.definitively

    nix-unit
    assayPkgs.assay
    assayPkgs.nixq
    assayPkgs.nixdrv
    assayPkgs.nixfetch
    assayPkgs.nixstore
    nixHash
    namaka
    nixt

    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
    cargo-llvm-cov
    cargo-nextest
    # llvm-cov/profdata for cargo-llvm-cov (rustup llvm-tools-preview not in nix rustc)
    llvmPackages.llvm

    systemd
    libinput

    direnv
    git
    gh
    jq
    nixpkgs-fmt
    pre-commit
    treefmt
    commitizen
    slumber
    lazysql

    alejandra
    actionlint
    deadnix
    beautysh
    biome
    yamlfmt
    taplo
    vulnix

    roam-code
    lean-ctx
    moon
    bun
    zlib
    pkgs.stdenv.cc.cc.lib
  ];

  languages = {
    rust = {
      enable = true;
      channel = "stable";
      components = ["rustfmt" "rust-analyzer"];
    };

    javascript = {
      enable = true;
      bun.enable = true;
    };
  };

  scripts = {
    prek-install = {
      exec = ''
        ${pkgs.prek}/bin/prek install -q --overwrite -c "$DEVENV_ROOT/.pre-commit-config.yaml"
        if cd "$DEVENV_ROOT" && git rev-parse --git-dir >/dev/null 2>&1; then
          HOOKS_DIR=$(git rev-parse --git-path hooks 2>/dev/null) || true
          if [ -n "$HOOKS_DIR" ] && [ -d "$HOOKS_DIR" ]; then
            rm -f "$HOOKS_DIR"/*.legacy
          fi
        fi
      '';
    };

    moon-sync = {
      exec = ''
        moon sync
      '';
    };

    format = {
      exec = ''
        treefmt
      '';
    };

  };

  tasks = {
    "devenv:git-hooks:install" = pkgs.lib.mkForce {
      after = ["devenv:files"];
      before = ["devenv:enterShell"];
      exec = ''
        prek-install
      '';
    };
  };

  git-hooks = {
    hooks = {
      deepsec = {
        enable = true;
        stages = ["pre-push"];
        name = "deepsec";
        description = "Run deepsec process on outgoing commits; blocks push on findings";
        pass_filenames = false;
        always_run = true;
        entry = "devenv shell -- bin/git-hooks/deepsec-pre-push";
      };
      moon-test = {
        enable = true;
        stages = ["pre-commit"];
        name = "moon test (assay)";
        description = "Run moon :test (assay across the repo)";
        pass_filenames = false;
        always_run = true;
        entry = "devenv shell -- assay run .";
      };
      # Coverage for assay crates lives in github:Industrial/assay.
      moon-coverage = {
        enable = false;
      };
    };
  };
}

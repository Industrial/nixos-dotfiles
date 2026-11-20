# Colocated suite for root flake.nix — the unified fleet flake.
#
# `inputs` is plain data and is read straight off the imported flake. `outputs` is called with
# the root inputs as resolved from flake.lock (common/assay/nixos.nix's resolver — the same
# algorithm as Nix's call-flake.nix), so the claims are about the outputs the flake really
# produces. Everything is lazy: reading a deploy node's fields does not evaluate the host.
let
  assay = import ./common/assay/default.nix;
  nixos = import ./common/assay/nixos.nix;
  lib = nixos.lib;

  flake = import ./flake.nix;
  inherit (flake) inputs;
  outputs = flake.outputs (nixos.flakeInputs // {self = outputs;});

  hosts = (import ./common/fleet.nix).names;
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  node = outputs.deploy.nodes.drakkar;
in
  assay.suite "flake" {
    # ---- inputs ---------------------------------------------------------------------------

    tracksNixpkgsUnstable = assay.eq inputs.nixpkgs.url "github:nixos/nixpkgs/nixpkgs-unstable";
    hasDeployRs = assay.eq inputs.deploy-rs.url "github:serokell/deploy-rs";
    # The prebuilt databases features/cli/nix-index consumes.
    hasNixIndexDatabase = assay.eq inputs.nix-index-database {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Source only: features/cli/shell-init copies completers out of it at build time.
    # Pinned by rev, below upstream's git completer rewrite: `nix flake update` must not move
    # it past bin/ci/shell-budget unnoticed (see the comment in flake.nix).
    hasNuScripts = assay.eq inputs.nu-scripts {
      url = "github:nushell/nu_scripts/19c49e09e1970a11db235fd38477dd5fa44e56bc";
      flake = false;
    };
    nuScriptsLockMatchesPin = assay.eq lock.nodes.nu-scripts.locked.rev "19c49e09e1970a11db235fd38477dd5fa44e56bc";
    # The fleet's own Rust tools come from the checkout, as plain sources.
    rustToolsAreLocalSources = assay.eq [inputs.oomkiller-src inputs.nixos-update-notifier-src] [
      {
        url = "path:./rust/tools/oomkiller";
        flake = false;
      }
      {
        url = "path:./rust/tools/nixos-update-notifier";
        flake = false;
      }
    ];
    # Deliberately NOT following nixpkgs: its FOD hash and interpreter pin are fixed against
    # its own nixpkgs (see the comment in flake.nix).
    # Its lib-only inputs (systems, flake-parts, treefmt-nix) do follow the root; nixpkgs not.
    llmAgentsKeepsItsOwnNixpkgs = assay.eq ((inputs.llm-agents.inputs or {}) ? nixpkgs) false;
    # Links against the root pin fail (-lsqlite3) until Industrial/assay#11 lands.
    assayKeepsItsOwnNixpkgs = assay.eq ((inputs.assay.inputs or {}) ? nixpkgs) false;
    # Everything else that carries a nixpkgs follows the root's.
    nixpkgsFollowedWhereSafe =
      assay.eq
      (map (n: inputs.${n}.inputs.nixpkgs.follows or null) ["hyprland" "nixos-hardware" "deploy-rs" "comin" "stylix" "nixvim" "emerald"])
      ["nixpkgs" "nixpkgs" "nixpkgs" "nixpkgs" "nixpkgs" "nixpkgs" "nixpkgs"];
    # The lock holds exactly three nixpkgs: the root's, llm-agents' and assay's.
    lockHasThreeNixpkgs =
      assay.eq
      (builtins.length (lib.filter (n: lib.toLower (n.locked.repo or "") == "nixpkgs" || lib.hasSuffix "nixexprs.tar.xz" (n.locked.url or "") || (n.locked.repo or "") == "nixpkgs.lib") (builtins.attrValues lock.nodes)))
      3;
    # checks.flake-lock-follows has nothing to report on the committed lock.
    lockFollowsCheckIsClean = assay.eq outputs.checks.x86_64-linux.flake-lock-follows.report "";
    # One nix-community key, the one nix-community.org/cache publishes.
    trustsOnlyTheRealNixCommunityKey =
      assay.eq flake.nixConfig.extra-trusted-public-keys ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
    # Every input the lock resolves is one the flake declares, and vice versa.
    lockMatchesDeclaredInputs =
      assay.eq (builtins.attrNames nixos.flakeInputs) (builtins.attrNames inputs);

    # `outputs` takes self plus the rest as `inputs @ {...}`.
    outputsTakeSelfAndAllInputs = assay.eq (builtins.functionArgs flake.outputs) {self = false;};

    # ---- outputs --------------------------------------------------------------------------

    # One nixosConfiguration per fleet host, plus the installer ISO's.
    hasEveryHostConfiguration =
      assay.eq (builtins.attrNames outputs.nixosConfigurations) (lib.sort (a: b: a < b) (hosts ++ ["installer"]));
    hasDrakkar = assay.eq (outputs.nixosConfigurations ? drakkar) true;
    buildsTheInstallerIso = assay.eq (outputs.packages.x86_64-linux ? installer-iso) true;

    # Deploy nodes come from the same host list — genAttrs hosts mkDeployNode — so a host
    # cannot be deployable without a configuration, or the reverse.
    hasDeployNodes = assay.eq (builtins.attrNames outputs.deploy.nodes) (lib.sort (a: b: a < b) hosts);
    deployNodeIsNamedForItsHost =
      assay.eq (lib.mapAttrs (_: n: n.hostname) outputs.deploy.nodes) (lib.genAttrs hosts (h: h));
    # Root owns the system profile; deploy logs in as tom and escalates with passwordless sudo
    # (features/fleet/operator-ssh.nix).
    activatesAsRootOverTomsSsh =
      assay.eq [node.profiles.system.user node.profiles.system.sshUser node.profiles.system.interactiveSudo] ["root" "tom" false];
    # The dbus monitor behind magic rollback can time out while systemd restarts mid-switch.
    rollbackFeaturesAreOff =
      assay.eq [node.profiles.system.magicRollback node.profiles.system.autoRollback] [false false];

    stigReportForEveryHost = assay.eq (builtins.attrNames outputs.stigReport) (lib.sort (a: b: a < b) hosts);
    formatterIsAlejandra = assay.eq (lib.getName outputs.formatter.x86_64-linux) "alejandra";
  }

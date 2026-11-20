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
    hasNuScripts = assay.eq inputs.nu-scripts {
      url = "github:nushell/nu_scripts";
      flake = false;
    };
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
    llmAgentsKeepsItsOwnNixpkgs = assay.eq (inputs.llm-agents ? inputs) false;
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

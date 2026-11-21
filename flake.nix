{
  description = "Industrial NixOS dotfiles — unified fleet flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Every input follows this nixpkgs unless it is listed in `separateNixpkgs` (in
    # `outputs` below) with a reason. `checks.<system>.flake-lock-follows` enforces it
    # against flake.lock, so a new input that drags in its own nixpkgs fails CI.

    # Shared library-only inputs, hoisted so the lock holds one copy of each instead of
    # one per consumer. None of them carries packages: they are systems lists, flake
    # helpers and the flake-compat shim, so a single pin cannot change what gets built.
    systems.url = "github:nix-systems/default";

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Follows nixpkgs, against the Hyprland wiki's default advice, on purpose. The wiki
    # (content/nix/cachix.md) warns that overriding nixpkgs makes the Hyprland Cachix
    # useless. This fleet does not use that cache: hyprland.cachix.org is in neither
    # nixConfig nor nix.settings (features/nixos/default.nix), so Hyprland already builds
    # from source and the warning costs nothing here. What a second nixpkgs does cost is
    # the mesa mismatch the wiki documents (installing-hyprland-on-nixos.md, Hyprland
    # issue #5148): Hyprland linked against one mesa, the system's GL driver from another.
    # One nixpkgs removes that class of bug. Hyprland's own needs (lua5_5 for the Lua
    # config) were checked against the root pin on 2026-11-20: lua5_5 5.5.1, mesa 26.3.0.
    # Revisit only if the fleet adopts the Hyprland Cachix; then drop this follows.
    hyprland = {
      url = "github:hyprwm/hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pre-commit-hooks.inputs.flake-compat.follows = "flake-compat";
    };

    quickshell = {
      url = "github:quickshell-mirror/quickshell/28771c7c74b42e20afca0b1b63980cb46515537c";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.quickshell.follows = "quickshell";
    };

    # Tracks master on purpose. nixos-hardware publishes no releases and no stable
    # branches: master is its only line, the two tags are not releases (one is literally
    # `not-a-release`), and its README pins `github:NixOS/nixos-hardware/master`. Its
    # modules are hardware quirks that are meant to track the current kernel, so a frozen
    # tag would only drift. flake.lock pins the exact rev, which is what makes it
    # reproducible; `master` only says where `nix flake update` moves it. Follows nixpkgs
    # as its README shows: its own nixpkgs only feeds its formatter and tests.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.systems.follows = "systems";
    };

    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.systems.follows = "systems";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    oomkiller-src = {
      url = "path:./rust/tools/oomkiller";
      flake = false;
    };

    nixos-update-notifier-src = {
      url = "path:./rust/tools/nixos-update-notifier";
      flake = false;
    };

    # Deliberately does NOT follow nixpkgs, for now. Built against the root pin, the
    # locked assay (fd6b48ca) fails to link: `ld: cannot find -lsqlite3`. Its
    # buildRustPackage declares only pkg-config, and rusqlite's libsqlite3-sys (not
    # `bundled`) emits `-lsqlite3` with no sqlite in buildInputs. Under its own pin
    # (rustc 1.97.1) the binary links without it (no libsqlite3 in NEEDED); under the
    # root pin (rustc 1.99.1) the linker demands it. Tried 2026-11-20 (drv
    # h46igm72...-assay-0.3.0). The fix belongs upstream (Industrial/assay#11):
    # `buildInputs = [pkgs.sqlite]` in Industrial/assay's mkCrate. Once that lands, add
    # `inputs.nixpkgs.follows = "nixpkgs"` and drop assay from `separateNixpkgs` below.
    assay.url = "github:Industrial/assay";

    emerald = {
      url = "github:Industrial/emerald";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    voltaic = {
      url = "github:Industrial/voltaic";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
      inputs.flake-compat.follows = "flake-compat";
    };

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
      # nixlib is nix-community/nixpkgs.lib, a lib-only mirror of nixpkgs. The root
      # nixpkgs exposes the same `lib`, so a second copy buys nothing.
      inputs.nixlib.follows = "nixpkgs";
    };

    claude-desktop = {
      url = "github:poeck/claude-desktop-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure Boot for NixOS: lzbt, a Rust bootloader installer that reads bootspec and
    # signs what it puts on the ESP. It replaces the Python systemd-boot installer only on
    # a host with features.hardening.secureBoot.enable (features/nixos/boot, ADR-0007);
    # everywhere else the module is imported but inert. nixpkgs dropped lanzaboote-tool, so
    # this is the only source. Pinned to a release tag. Every input it brings follows ours:
    # crane has no inputs, rust-overlay and the git-hooks source (unused by its outputs)
    # take our nixpkgs and flake-compat. Exception to the Voltaic + id_effect rule granted
    # for GH-184: adopting upstream, not writing a new installer.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pre-commit.inputs.flake-compat.follows = "flake-compat";
    };

    # Pull-based convergence; not packaged in nixpkgs. See ADR-0002.
    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.flake-compat.follows = "flake-compat";
    };

    # numtide's package set for coding agents — the source of openhands-agent-canvas
    # (features/ai/openhands). OpenHands is absent from nixpkgs entirely: verified
    # 2026-11-04 against this repo's pin, nixos-unstable and master, with no packaging PR
    # open, so there is nothing to wait for here.
    #
    # Deliberately does NOT follow nixpkgs, unlike most inputs above. It pins its own
    # nixpkgs (885ba4d0) and the package is a buildNpmPackage whose npm-deps hash and
    # wrapper are fixed against that pin plus a specific uv and python3. Overriding nixpkgs
    # would invalidate the FOD hash and discard the interpreter pin that keeps uvx from
    # fetching an unsupported CPython at runtime. One extra nixpkgs in the lock is the
    # cheaper trade.
    #
    # Builds from source here. The flake declares numtide's binary cache in nixConfig, but
    # Nix ignores substituters from a non-root flake, so it is not in effect — adding it to
    # the fleet's nix settings would be a separate trust decision, not a side effect of
    # installing a package.
    #
    # Its library-only inputs (systems, flake-parts, treefmt-nix) do follow the root:
    # they shape the flake's outputs, not the derivations, so the packages keep building
    # from numtide's nixpkgs. Verified by an unchanged openhands-agent-canvas drvPath.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.systems.follows = "systems";
      inputs.flake-parts.follows = "flake-parts";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    # Prebuilt nix-index databases, so `comma` can answer "which package ships this
    # binary?" immediately instead of each host spending a multi-hour local `nix-index`
    # run to build the same index.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Source-only: the upstream Nushell script collection. Consumed in wave 6 to emit a
    # selected set of completers at build time; nothing from it is vendored into this repo.
    #
    # Pinned to a rev, not tracking the default branch: the input bump in 5dae8688 brought
    # upstream's rewritten git completer (64 KB -> 106 KB), which alone added ~8 ms to the
    # replayed interactive startup and put bin/ci/shell-budget over its 4.0x budget on
    # every run since (35.3 ms vs 27.6 ms on drakkar, same harness, only that file
    # swapped). Moving this pin is a startup-budget decision: re-run bin/ci/shell-budget
    # with the new rev before bumping it, and drop "git" from cli.shellInit.completers if
    # the rewrite is wanted.
    nu-scripts = {
      url = "github:nushell/nu_scripts/19c49e09e1970a11db235fd38477dd5fa44e56bc";
      flake = false;
    };
  };

  nixConfig = {
    extra-substituters = ["https://nix-community.cachix.org"];
    # The one nix-community signing key, as published at https://nix-community.org/cache/
    # and by the Cachix API (app.cachix.org/api/v1/cache/nix-community), checked
    # 2026-11-20. Same key as nix.settings in features/nixos/default.nix.
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  outputs = inputs @ {self, ...}: let
    inherit (inputs.nixpkgs) lib;
    system = "x86_64-linux";
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    hosts = (import ./common/fleet.nix).names;
    mkHost = import ./lib/mk-host.nix {inherit inputs;};
    nixosConfigurations =
      lib.genAttrs hosts mkHost
      // {
        # Installer ISO configuration
        installer = lib.nixosSystem {
          inherit system;
          modules = [./installer/configuration.nix];
        };
      };
    deployLib = inputs.deploy-rs.lib.${system};

    # Root inputs allowed to bring their own nixpkgs, each with the reason. Everything else
    # must resolve every nixpkgs-shaped node it reaches in flake.lock to the root's.
    separateNixpkgs = {
      llm-agents = "FOD hashes and the uv/python pin are fixed against its own nixpkgs";
      assay = "fails to link against the root pin (-lsqlite3); fix pending in Industrial/assay#11";
    };

    # Walks flake.lock and fails when an input reaches a nixpkgs (github nixpkgs,
    # nixpkgs.lib, or a channel nixexprs tarball) other than the root's, unless the root
    # input it hangs off is in `separateNixpkgs`. Also fails on a stale allowlist entry.
    flakeLockFollows = let
      lock = builtins.fromJSON (builtins.readFile ./flake.lock);
      inherit (lock) nodes;
      rootInputs = nodes.${lock.root}.inputs;
      # A lock input is a node name, or a follows path walked from the root.
      resolve = spec:
        if builtins.isString spec
        then spec
        else lib.foldl' (node: name: resolve nodes.${node}.inputs.${name}) lock.root spec;
      rootNixpkgs = resolve rootInputs.nixpkgs;
      isNixpkgs = node: let
        l = node.locked or {};
      in
        builtins.elem (lib.toLower (l.repo or "")) ["nixpkgs" "nixpkgs.lib"]
        || lib.hasSuffix "nixexprs.tar.xz" (l.url or "");
      # Every node reachable from root input `k`, once each (the graph has cycles, e.g.
      # caelestia-shell <-> caelestia-cli), with the first input path that reached it.
      reachable = k:
        builtins.genericClosure {
          startSet = [
            {
              key = resolve rootInputs.${k};
              path = [k];
            }
          ];
          operator = item:
            lib.mapAttrsToList (name: spec: {
              key = resolve spec;
              path = item.path ++ [name];
            }) (nodes.${item.key}.inputs or {});
        };
      offendersOf = k:
        map (item: "${lib.concatStringsSep "/" item.path} -> ${item.key}")
        (lib.filter (item: item.key != rootNixpkgs && isNixpkgs nodes.${item.key}) (reachable k));
      offenders = lib.concatMap offendersOf (lib.filter (k: !(separateNixpkgs ? ${k})) (builtins.attrNames rootInputs));
      stale = lib.filter (k: !(rootInputs ? ${k}) || offendersOf k == []) (builtins.attrNames separateNixpkgs);
      report =
        lib.optionalString (offenders != []) ''
          These inputs reach a nixpkgs other than the root's. Add
          `inputs.<name>.follows = "nixpkgs"` in flake.nix, or list the root input in
          `separateNixpkgs` with a reason:
          ${lib.concatMapStrings (o: "  ${o}\n") offenders}''
        + lib.optionalString (stale != []) ''
          These `separateNixpkgs` entries no longer pin a separate nixpkgs (or are not
          inputs at all); remove them:
          ${lib.concatMapStrings (s: "  ${s}\n") stale}'';
    in
      pkgs.runCommand "flake-lock-follows" {inherit report;} (
        if report == ""
        then "touch $out"
        else ''
          printf '%s' "$report" >&2
          exit 1
        ''
      );
    mkDeployNode = hostname: {
      inherit hostname;
      profiles.system = {
        # Profile owner must be root for NixOS system activation.
        # SSH as tom; escalate via passwordless sudo (operator-ssh.nix).
        user = "root";
        sshUser = "tom";
        interactiveSudo = false;
        # Disable rollback features to avoid dbus subscription timeout during switch.
        # The dbus monitor can fail if systemd/journald are restarting mid-switch.
        magicRollback = false;
        autoRollback = false;
        path = deployLib.activate.nixos nixosConfigurations.${hostname};
      };
    };
  in {
    inherit nixosConfigurations;

    # Build with: nix build .#installer-iso
    packages.${system}.installer-iso = nixosConfigurations.installer.config.system.build.isoImage;

    deploy = {
      type = "deploy";
      nodes = lib.genAttrs hosts mkDeployNode;
    };

    # Anduril NixOS STIG VM tests — one derivation per verified control, named
    # `stig-V-<id>`. Seven controls cannot be verified by evaluating configuration at all
    # (see security.stig.deferredVerification); these are what prove them.
    # Run all: moon run stig-vm-test     One: nix build .#checks.<system>.stig-V-268140
    stigVmTests = import ./features/security/stig/tests/vm {inherit pkgs lib;};

    # Per-host compliance report — the artifact an assessor asks for. This benchmark ships no
    # OVAL/SCAP content (all 103 checks are manual), so nothing off the shelf can produce it.
    #   nix build .#stigReport.muninn && cat result/report.md
    stigReport = lib.genAttrs hosts (hostname:
      import ./features/security/stig/lib/report.nix {
        inherit pkgs lib;
        inherit (nixosConfigurations.${hostname}) config;
      });

    # deploy-rs's checks, once per node (`deploy-schema-<host>`, `deploy-activate-<host>`)
    # rather than once over all of them. The combined pair evaluates every host in one
    # attribute, which needs more than 11 GB of evaluator memory and so cannot be evaluated
    # on a 16 GB CI runner at all (bin/ci/flake-checks); per node, each is one host's worth.
    # Same checks, same schema: each node is validated inside the full `deploy` attrset
    # with only its own entry under `nodes`.
    checks.${system} =
      lib.foldl' (acc: host:
        acc
        // lib.mapAttrs' (name: lib.nameValuePair "${name}-${host}")
        (deployLib.deployChecks (self.deploy // {nodes = {${host} = self.deploy.nodes.${host};};})))
      {}
      hosts
      // (builtins.removeAttrs self.stigVmTests ["passthru"])
      # features/nix/vverify's VM test: a corrupted store path is reported.
      // {vverify-vm = import ./features/nix/vverify/test.nix {inherit pkgs;};}
      # vbuild's two-node test and fan-out benchmark (rust/tools/vbuild/vm-test.nix).
      // {vbuild-vm = import ./rust/tools/vbuild/vm-test.nix {inherit pkgs;};}
      # features/nixos/boot's Secure Boot path (GH-184): systemd-boot -> lanzaboote -> reboot
      # -> rollback to systemd-boot -> reboot, through OVMF and the ESP.
      // {lanzaboote-vm = import ./features/nixos/boot/test.nix {inherit pkgs inputs;};}
      # features/nix/vdaemon-proxy in a VM (#157).
      // {vdaemon-proxy-vm = import ./features/nix/vdaemon-proxy/test.nix {inherit pkgs;};}
      # ... and switched into and out of a running system.
      // {vdaemon-proxy-live-switch-vm = import ./features/nix/vdaemon-proxy/test-live-switch.nix {inherit pkgs;};}
      # ... in conformance mode, with builds and GCs racing the queries (#183).
      // {vdaemon-proxy-conformance-vm = import ./features/nix/vdaemon-proxy/test-conformance.nix {inherit pkgs;};}
      # features/nix/vpush's VM test: builds pushed to vcache, substituted by a fresh store.
      // {vpush-vm = import ./features/nix/vpush/test.nix {inherit pkgs;};}
      # features/nix/vfetch's VM test: a substitution goes through vfetch serve.
      // {vfetch-vm = import ./features/nix/vfetch/test.nix {inherit pkgs;};}
      # features/nixos/vfiles's VM test: add, remove, adopt, fall back, report drift.
      // {vfiles-vm = import ./features/nixos/vfiles/test.nix {inherit pkgs;};}
      # features/nix/vdeploy's VM test (#159): commits faster than a build, still converges.
      // {vdeploy-vm = import ./features/nix/vdeploy/test.nix {inherit pkgs;};}
      # features/nixos/vgen's VM test: prunes keep the booted, current and pinned
      # generations, the boot menu follows, and pins survive vgc.
      // {vgen-vm = import ./features/nixos/vgen/test.nix {inherit pkgs;};}
      // {flake-lock-follows = flakeLockFollows;};

    formatter.${system} = pkgs.alejandra;
  };
}

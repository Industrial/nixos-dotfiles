# Colocated suite for features/nix/vdeploy/test.nix — the VM test where commits land faster
# than a build takes and the agent still converges, and the dotfiles checkout is
# fast-forwarded (and refused when dirty).
#
# Evaluates the test's node (no VM is booted here; `nix build .#checks.x86_64-linux.vdeploy-vm`
# runs it), so these claims are about the machine under test.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test.nix {inherit pkgs;};
  inherit (test.nodes) machine;
  args = pkgs.lib.splitString " " machine.systemd.services.vdeploy.serviceConfig.ExecStart;
  argAfter = flag: builtins.elemAt args (1 + pkgs.lib.lists.findFirstIndex (a: a == flag) 0 args);
in
  assay.suite "vdeploy-vm-test" {
    named = assay.eq test.name "vm-test-run-vdeploy-vm";
    runsTheFeature = assay.eq (machine.systemd.services ? vdeploy) true;
    # The flake's host is the VM's own name; main comes from a local repository.
    evaluatesThisMachine = assay.eq [(argAfter "--host") (argAfter "--url")] ["machine" "/srv/origin"];
    # Polls faster than the 3 s between commits, so the poller sees most of them.
    pollsEveryTwoSeconds = assay.eq (argAfter "--interval") "2s";
    alicesCheckout = assay.eq [(argAfter "--dotfiles") (argAfter "--dotfiles-user")] ["/home/alice/.dotfiles" "alice"];
    # Offline: the Fetcher has nothing to substitute from, so the Builder builds.
    noSubstituters = assay.eq machine.nix.settings.substituters [];
    builderInTheStore = assay.eq (map (d: d.pname or d.name) machine.system.extraDependencies) ["busybox"];
    exporterOn = assay.eq machine.services.prometheus.exporters.node.enable true;
    # GH-221: the forge is local, so its commits are signed with the test key, which the node
    # trusts instead of GitHub's; signatures are required, as on the fleet.
    signedWithTheTestKey =
      assay.eq [(pkgs.lib.hasSuffix "-vdeploy-test-signing-key/public.asc" (toString (builtins.head machine.features.nix.vdeploy.trustedSigningKeys))) (builtins.elem "--require-signed" args)] [true true];
  }

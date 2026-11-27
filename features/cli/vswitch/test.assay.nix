# Colocated suite for features/cli/vswitch/test.nix, the VM test of the local rebuild
# (GH-241). Evaluates the test's node, so the claims are about the machine under test; no
# VM is booted here (`nix build .#checks.x86_64-linux.vswitch-vm` runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (pkgs) lib;

  test = import ./test.nix {inherit pkgs;};
  m = test.nodes.machine;
  spec = name: m.specialisation.${name}.configuration;
  probesOf = c: builtins.attrNames c.features.nix.vhealth.probes;
  wrapper = builtins.head (builtins.filter (p: (p.name or "") == "vswitch") m.environment.systemPackages);
in
  assay.suite "vswitch-vm-test" {
    named = assay.eq test.name "vm-test-run-vswitch-vm";
    # A generation whose probe cannot pass, and one whose probes all can.
    brokenHasADeadPort = assay.eq [(builtins.elem "dead-port" (probesOf (spec "broken"))) ((spec "broken").systemd.services ? liar)] [true true];
    goodHasNone = assay.eq (builtins.elem "dead-port" (probesOf (spec "good"))) false;
    # drakkar's restriction: the probes must run as vhealth, which the wrapper passes.
    restrictedLikeTheFleet = assay.eq (lib.sort lib.lessThan m.nix.settings.allowed-users) ["@wheel" "vhealth"];
    probesAsVhealth = assay.eq (lib.hasInfix "--health-as vhealth" wrapper.text) true;
    # A non-root operator, elevated by sudo only for the activation.
    aliceInWheel = assay.eq (builtins.elem "wheel" m.users.users.alice.extraGroups) true;
    # The real STIG base-safe profile (#241), as on mimir: audit on, signatures required, and
    # sudo asks wheel for a password (V-268156); the test answers it on a terminal.
    stigBaseSafe = assay.eq [m.security.auditd.enable m.nix.settings.require-sigs m.security.sudo.wheelNeedsPassword] [true true true];
  }

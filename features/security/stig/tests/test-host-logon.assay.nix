# Colocated suite for tests/test-host-logon.nix. Evaluates the test's node (no VM is booted
# here; `nix build .#checks.x86_64-linux.stig-test-host-logon` runs it), so these claims pin
# that the gate boots muninn's own configuration with both PAM controls in it, and what the
# test adds to that configuration.
let
  assay = import ../../../../common/assay/default.nix;
  nixos = import ../../../../common/assay/nixos.nix;
  inputs = nixos.flakeInputs;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (nixos) lib;

  test = import ./test-host-logon.nix {inherit pkgs inputs;};
  node = test.nodes.machine;
  # The script as the test driver gets it, evaluated: not the source text of the file.
  source = test.config.testScriptString;
  pamText = service: node.security.pam.services.${service}.text;
  user = "tom";
in
  assay.suite "stig-test-host-logon" {
    named = assay.eq test.name "vm-test-run-stig-test-host-logon";
    # The host's own configuration, not a model of it.
    bootsMuninn = assay.eq node.networking.hostName "muninn";
    carriesTheTestHostProfile = assay.eq node.security.stig.profile "test-host";
    carriesBothPamControls =
      assay.eq (map (id: builtins.elem id node.security.stig.implemented) ["V-268081" "V-268170"]) [true true];

    # The stacks under test are the ones the host renders.
    loginStackHasTheThreeCalls =
      assay.eq (map (needle: lib.hasInfix needle (pamText "login")) ["pam_faillock.so preauth" "pam_faillock.so authfail" "account required"]) [true true true];
    graphicalLogonGoesThroughLogin = assay.eq (builtins.match ".*auth substack login.*" (pamText "gdm-password") != null) true;
    # The way back in that the test walks: keys only over SSH, and sudo without a password.
    sshIsKeyOnly = assay.eq node.services.openssh.settings.PasswordAuthentication false;
    operatorSudoNeedsNoPassword =
      assay.eq (builtins.any (r: r.users == [user] && builtins.any (c: c.options == ["NOPASSWD"]) r.commands) node.security.sudo.extraRules) true;

    # What the test adds: one more key for the operator, and pamtester. Nothing else.
    addsATestKeyNextToTheEnrolledOnes = assay.eq (builtins.length node.users.users.${user}.openssh.authorizedKeys.keys > 1) true;
    addsPamtester = assay.eq (builtins.any (p: (p.pname or "") == "pamtester") node.environment.systemPackages) true;

    # The steps that make this a gate and not a rendering check.
    locksThroughTheGraphicalService = assay.eq (lib.hasInfix "pam_refuses(\"gdm-password\", PASSWORD)" source) true;
    locksAtTheConsole = assay.eq (lib.hasInfix "refused(3, USER, PASSWORD)" source) true;
    releasesOverSshWithSudo = assay.eq (lib.hasInfix "{ssh} sudo -n faillock --user {USER} --reset" source) true;
    acceptedAgainAfterTheRelease = assay.eq (lib.hasInfix "accepted(3, USER, PASSWORD)" source) true;
    weakPasswordRefused = assay.eq (lib.hasInfix "passwd took a short password" source) true;
  }

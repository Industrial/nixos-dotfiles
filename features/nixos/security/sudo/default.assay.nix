# Assay: sudo policy.
#
# Claims read the evaluated security.sudo options, and the generated sudoers text where the
# text is the artifact (extraConfig).
#
# Pinned as-is, and worth knowing: `timestamp_timeout=-1` means a successful sudo never
# expires for that terminal session, so after the first authentication every later sudo in
# that tty is passwordless. That is the module's deliberate trade (fewer security-key
# presses); a change to it should be a visible edit here.
let
  assay = import ../../../../common/assay/default.nix;
  nixos = import ../../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  sudo = cfg.security.sudo;
  # Defaults lines, whitespace-normalised, minus the ones NixOS writes on an empty system.
  defaultsOf = c:
    map (l: lib.concatStringsSep " " (builtins.match "(Defaults[^[:space:]]*)[[:space:]]+(.*)" l))
    (builtins.filter (lib.hasPrefix "Defaults") (lib.splitString "\n" c.security.sudo.extraConfig));
  addedDefaults = lib.subtractLists (defaultsOf nixos.baseline) (defaultsOf cfg);
in
  assay.suite "sudo" {
    sudoEnabled = assay.eq sudo.enable true;
    wheelNeedsPassword = assay.eq sudo.wheelNeedsPassword true;
    # Only wheel members can even execute the sudo binary (it is not world-executable).
    execWheelOnly = assay.eq sudo.execWheelOnly true;
    # The only Defaults this module adds.
    credentialsNeverTimeOut = assay.eq addedDefaults ["Defaults timestamp_timeout=-1"];
    # sudo-rs would replace this policy wholesale.
    notSudoRs = assay.eq cfg.security.sudo-rs.enable false;
  }

# Assay: YubiKey support -- tools, smart-card daemon, udev access, and (not) PAM.
#
# Claims read the evaluated config; the udev rules are matched as text because the generated
# rules file IS text.
#
# Security posture, pinned as it actually is:
#   - The module's comments say login, sudo and su are "configured to use YubiKey", but the
#     PAM service entries are empty: no pam_u2f / pam_yubico line is generated, so a YubiKey
#     is NOT a factor for any of them. The claims below assert that absence so that wiring
#     it up is a visible change here, not a comment that happens to come true.
#   - Every rule grants MODE 0664 to GROUP users, i.e. raw USB read/write on the key for any
#     member of `users`, not just the operator.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  ruleLines = c:
    builtins.filter (l: lib.hasPrefix "SUBSYSTEM" l)
    (map lib.trim (lib.splitString "\n" c.services.udev.extraRules));
  # Only the rules this feature adds; NixOS writes a few of its own on any system.
  rules = lib.subtractLists (ruleLines nixos.baseline) (ruleLines cfg);
  ruleRe = ''SUBSYSTEM=="usb", ATTR[{]idVendor[}]=="([0-9a-f]{4})", ATTR[{]idProduct[}]=="([0-9a-f]{4})", MODE="([0-7]+)", GROUP="([a-z]+)"'';
  parsed = map (builtins.match ruleRe) rules;
  field = i: lib.unique (map (m: builtins.elemAt m i) parsed);
  products = map (m: builtins.elemAt m 1) parsed;
  pad = n: lib.fixedWidthString 4 "0" (toString n);
  # The rendered PAM stack for a service is the artifact; it must be what an empty system has.
  pamUnchanged = svc: cfg.security.pam.services.${svc}.text == nixos.baseline.security.pam.services.${svc}.text;
  pamMentionsKey = svc: builtins.match ".*(pam_u2f|pam_yubico).*" cfg.security.pam.services.${svc}.text != null;
in
  assay.suite "yubikey" {
    installsManager = assay.eq (nixos.hasPackage cfg "yubikey-manager") true;
    installsPersonalization = assay.eq (nixos.hasPackage cfg "yubikey-personalization") true;
    installsPivTool = assay.eq (nixos.hasPackage cfg "yubico-piv-tool") true;
    installsYubicoPam = assay.eq (nixos.hasPackage cfg "yubico-pam") true;
    installsLibfido2 = assay.eq (nixos.hasPackage cfg "libfido2") true;

    # PC/SC daemon: PIV and OpenPGP applets go through it.
    pcscdEnabled = assay.eq cfg.services.pcscd.enable true;

    everyUdevRuleParses = assay.eq (builtins.all (m: m != null) parsed) true;
    udevRulesOnlyMatchYubico = assay.eq (field 0) ["1050"];
    # Exactly the ids the module lists: 0010, 0110-0116, 0120-0200 (counted like decimals,
    # so 0x011a-0x011f and friends are skipped). Note the YubiKey 5 series (0x0401-0x0407)
    # is not among them.
    udevCoversTheProductIds =
      assay.eq products (["0010"] ++ map pad (lib.range 110 116 ++ lib.range 120 200));
    udevGrantsGroupUsersReadWrite =
      assay.eq {
        mode = field 2;
        group = field 3;
      } {
        mode = ["0664"];
        group = ["users"];
      };

    # See the header: PAM is not wired to the key.
    pamStacksUnchanged = assay.eq (map pamUnchanged ["login" "sudo" "su"]) [true true true];
    noKeyModuleInLoginSudoSu = assay.eq (map pamMentionsKey ["login" "sudo" "su"]) [false false false];
    u2fPamModuleOff = assay.eq cfg.security.pam.u2f.enable false;
  }

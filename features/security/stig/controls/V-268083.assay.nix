# Colocated suite: V-268083 — consent banner on SSH logon.
let
  assay = import ./../../../../common/assay/default.nix;
  banner = import ./../lib/dow-banner.nix;
  mod = import ./V-268083.nix {};
  text = mod.environment.etc."ssh/banner".text;
in
  assay.suite "stig-V-268083" {
    usesTheSharedBanner = assay.eq text banner.multiline;
    # sshd is pointed at the file the text is written to. `settings.Banner` is a path;
    # `services.openssh.banner`, which the fix text names, no longer exists in nixpkgs.
    sshdSendsThatFile = assay.eq mod.services.openssh.settings.Banner "/etc/ssh/banner";
    doesNotSetTheRemovedOption = assay.eq (mod.services.openssh ? banner) false;
    # Identical text to the console banner — three controls, one notice.
    matchesConsoleBanner = assay.eq text (import ./V-268082.nix {}).services.getty.helpLine;
    usesDoWWording = assay.eq (builtins.match ".*Department of Defense.*" text) null;
  }

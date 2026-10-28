# Colocated suite: V-268153 — baseline change notification via AIDE.
let
  assay = import ./../../../../common/assay/default.nix;
  nixpkgsLib = (import <nixpkgs> {}).lib;

  control = aideMailTo:
    import ./V-268153.nix {
      lib = nixpkgsLib;
      pkgs = {
        aide = "aide-pkg";
        system-sendmail = "sendmail-pkg";
      };
      config.security.stig = {inherit aideMailTo;};
    };

  verdict = mod: (builtins.head mod.assertions).assertion;

  unset = control null;
  configured = control "security@example.com";
in
  assay.suite "stig-V-268153" {
    # No destination means every report is discarded, so the control must refuse.
    refusesWithoutADestination = assay.eq (verdict unset) false;
    messageRejectsThePlaceholder =
      assay.eq (builtins.match ".*notareal\\.email.*" (builtins.head unset.assertions).message != null) true;
    acceptsADestination = assay.eq (verdict configured) true;

    installsAide = assay.eq configured.environment.systemPackages ["aide-pkg"];

    # The config file must be read-only, per the fix text.
    configIsReadOnly = assay.eq configured.environment.etc."aide.conf".mode "0444";

    # Watches the paths that constitute "baseline configuration" on NixOS: generated /etc and
    # the bootloader. The store itself is immutable, so watching it would be noise.
    watchesEtc = assay.eq (builtins.match ".*/etc    Config.*" configured.environment.etc."aide.conf".text != null) true;
    watchesBoot = assay.eq (builtins.match ".*/boot   Full.*" configured.environment.etc."aide.conf".text != null) true;
    # machine-id and mtab change for benign reasons; flagging them would drown the signal.
    excludesVolatilePaths =
      assay.eq (builtins.match ".*!/etc/machine-id.*" configured.environment.etc."aide.conf".text != null) true;

    # A systemd timer, not the fix text's cron job piping to /bin/mail — which does not exist
    # on NixOS.
    usesSystemdNotCron = assay.eq (configured.systemd.services.stig-aide-check.startAt) "Sun 00:00";
    doesNotUseBinMail =
      assay.eq (builtins.match ".*/bin/mail.*" configured.systemd.services.stig-aide-check.script) null;

    # Re-initialises when there is no database, so a comin convergence does not produce a
    # report in which every file looks tampered with.
    initialisesOnFirstRun =
      assay.eq (builtins.match ".*--init.*" configured.systemd.services.stig-aide-check.script != null) true;
  }

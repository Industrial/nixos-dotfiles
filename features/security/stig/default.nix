# Anduril NixOS STIG baseline — option surface.
#
# Composition is by IMPORT, not by a flag: `profiles/base-safe.nix` and `profiles/full.nix`
# each import the control modules they carry, the same way every other feature in this repo
# works. The options below are declarative metadata that `lib/report.nix` reads to produce the
# compliance report; they do not gate any control.
#
# See data/PROVENANCE.md for the benchmark and docs/security/stig-triage.md for the
# per-control classification.
{
  config,
  lib,
  ...
}: {
  options.security.stig = {
    pwquality = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.int lib.types.str);
      default = {};
      example = {
        ucredit = -1;
        difok = 8;
      };
      description = ''
        libpwquality settings, rendered to /etc/security/pwquality.conf.

        Six separate controls (V-268126, V-268127, V-268128, V-268129, V-268145, V-268169)
        each require one setting in that single file, and every one of their fix texts assigns
        `environment.etc."/security/pwquality.conf".text` directly. Applied literally that is
        six conflicting definitions of one `str` option, so the published fix texts cannot all
        be followed at once — they are mutually exclusive.

        This attrset is the fix: each control contributes its own key, attrsets merge, and the
        file is rendered once here. nixpkgs has no pwquality module of its own, so there is
        nothing to collide with.

        (The published fix texts also use a leading slash — `"/security/pwquality.conf"` —
        which would render to /etc//security/pwquality.conf.)
      '';
    };
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether a STIG baseline is in effect on this host. Set by the stig profiles rather
        than by hand; the report uses it to decide whether to score the host at all.
      '';
    };

    profile = lib.mkOption {
      type = lib.types.enum ["none" "base-safe" "full"];
      default = "none";
      description = ''
        Which baseline this host carries. "base-safe" is the subset with no interactive cost;
        "full" is all 103 controls and is intended for VM-test targets, not for workstations.
      '';
    };

    implemented = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        The control ids this host actually carries, derived by each stig profile from its own
        module import list rather than hand-maintained.

        `lib/report.nix` reads this to know what to score. Keeping a second roster of 68 ids
        by hand would drift from the imports, and the report would then claim controls the
        host does not have — which is worse than no report.
      '';
    };

    satisfiedExternally = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = lib.literalExpression ''
        {
          "V-268144" = "Root filesystem sits inside a LUKS container; see hosts/*/disko.nix.";
        }
      '';
      description = ''
        Controls satisfied by something outside this module set, mapped to the evidence.

        Not every requirement is a NixOS option. V-268144 ("protect the confidentiality and
        integrity of all information at rest", CAT I) is decided by the disk layout: every
        host's `hosts/<name>/disko.nix` puts the root filesystem inside a LUKS container, and
        each `disko.assay.nix` asserts it. There is nothing for a control module to declare,
        yet the requirement is genuinely met.

        Without this, the report would call such a control "Not Implemented" — understating a
        CAT I control that is in fact satisfied, which is as misleading as overstating one.
        The value must cite checkable evidence (a file that asserts the property), not merely
        claim the control is fine.
      '';
    };

    requiresReboot = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = lib.literalExpression ''
        {
          "V-268092" = "adds audit=1 to the kernel command line.";
        }
      '';
      description = ''
        Controls that are configured correctly but cannot take effect until the host reboots,
        mapped to the reason.

        Kernel command line parameters are the usual case: `switch-to-configuration switch`
        activates a new generation without changing the running kernel's cmdline, so
        /proc/cmdline keeps the booted generation's parameters. The report renders these as
        "Configured (pending reboot)" — NOT compliant, because a host that will comply after a
        reboot does not comply now.
      '';
    };

    deferredVerification = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = lib.literalExpression ''
        {
          "V-268117" = "journal directory mode is set by systemd-journald at runtime; only a booted machine can show it.";
        }
      '';
      description = ''
        Controls whose requirement cannot be observed by evaluating the configuration, mapped
        to the reason why. Journald file modes, etc-activation directory permissions and
        stored password hashes are runtime state; no amount of static analysis can speak to
        them.

        This exists so that "satisfied by systemd's defaults" cannot quietly become a
        compliance claim with nothing behind it. Registration carries an obligation, enforced
        from both sides:

          - each listed control's colocated suite asserts it is registered here with a
            written reason, so a control cannot be silently treated as proven; and
          - `tests/vm/deferred.assay.nix` asserts every registered control has a VM test
            spec that inspects a booted machine, so registration cannot become a parking
            space for work nobody did.

        A registered control is therefore verified by `moon run stig-vm-test`, not by
        `moon run test`. The report should render it as compliant-by-VM-test and name the
        test, rather than claiming it from configuration it cannot see.
      '';
    };

    exclude = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = lib.literalExpression ''
        {
          "V-268079" = "No emergency or temporary accounts exist on this host.";
        }
      '';
      description = ''
        Controls deliberately not applied, mapped to the written justification. The report
        renders these as "Not Applicable" with the reason, which is the artifact an assessor
        asks for. An empty justification is useless — say why, not that.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (config.security.stig.pwquality != {}) {
      # Rendered without spaces around `=` to match the form the checks grep for
      # (e.g. `grep ucredit /etc/security/pwquality.conf` expecting `ucredit=-1`).
      environment.etc."security/pwquality.conf".text =
        lib.concatStringsSep "\n"
        (lib.mapAttrsToList (k: v: "${k}=${toString v}") config.security.stig.pwquality)
        + "\n";
    })

    (lib.mkIf (config.security.audit.enable != false) {
      # Ordering, and it is load-bearing.
      #
      # A watch rule (`-w <path>`) cannot be loaded if its target does not exist: auditctl
      # reports "Error sending add rule data request (No such file or directory)" and ABORTS
      # THE ENTIRE RULES FILE, so not one rule is loaded and the host runs unaudited.
      #
      # Two controls provision their watch targets with systemd-tmpfiles because the paths do
      # not exist on a stock system — V-268166 (/var/log/lastlog) and V-268097
      # (/var/cron/tabs) — and V-268167 does the same for /etc/security/opasswd. By default
      # the rule loader races tmpfiles and usually wins, which is how this was found: the VM
      # tests failed with the audit subsystem down and auditctl pointing at exactly those
      # two lines.
      #
      # Ordering after systemd-tmpfiles-setup closes the race. Verified by
      # tests/vm/audit.nix, whose readiness check now fails loudly if the rule set did not
      # load rather than reporting a confusing single-control miss.
      systemd.services.audit-rules-nixos = {
        after = ["systemd-tmpfiles-setup.service"];
        wants = ["systemd-tmpfiles-setup.service"];
      };
    })
  ];
}

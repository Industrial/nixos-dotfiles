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

  config = lib.mkIf (config.security.stig.pwquality != {}) {
    # Rendered without spaces around `=` to match the form the checks grep for
    # (e.g. `grep ucredit /etc/security/pwquality.conf` expecting `ucredit=-1`).
    environment.etc."security/pwquality.conf".text =
      lib.concatStringsSep "\n"
      (lib.mapAttrsToList (k: v: "${k}=${toString v}") config.security.stig.pwquality)
      + "\n";
  };
}

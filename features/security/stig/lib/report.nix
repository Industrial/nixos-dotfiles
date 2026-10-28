# Compliance report generator.
#
# Produces, for one evaluated host, the artifact an assessor actually asks for: every control
# in the benchmark, its severity and CCI mappings, its status, and — where it is compliant —
# the concrete reason to believe that.
#
# Why this exists at all: the Anduril NixOS STIG ships NO OVAL/SCAP content. Every one of its
# 103 checks is a manual shell command (`check-content-ref name="M"` on all of them), so no
# SCC or OpenSCAP run can grade a NixOS host against it. There is nothing off the shelf to
# produce this, which is why it is generated from the configuration instead.
#
# Status is DERIVED from the evaluated config, never hand-maintained:
#
#   Not Applicable               in security.stig.exclude, with the written justification
#   Compliant (external evidence) in security.stig.satisfiedExternally — met outside this
#                                module set (disk layout, physical controls), citing evidence
#   Configured (pending reboot)  in security.stig.requiresReboot — correct but not yet in effect
#   Compliant (VM test)          in security.stig.deferredVerification; runtime-only, proven by
#                                `moon run stig-vm-test`
#   Compliant (configuration)    implemented and provable by evaluating the config
#   Not Implemented              in the benchmark, absent from this host's profile
#
# The honest distinctions are the point. "Configured (pending reboot)" exists because muninn
# reported findings for V-268092/V-268093 after a successful switch: a running kernel keeps the
# command line it booted with. A report that called those compliant would have been wrong on a
# live host.
{
  pkgs,
  lib,
  config,
}: let
  stig = import ./parse-xccdf.nix;
  manifest = import ./manifest.nix;

  cfg = config.security.stig;
  hostName = config.networking.hostName or "unknown";

  catOf = sev:
    {
      high = "CAT I";
      medium = "CAT II";
      low = "CAT III";
    }
    .${
      sev
    }
    or sev;

  statusOf = id:
    if cfg.exclude ? ${id}
    then {
      status = "Not Applicable";
      detail = cfg.exclude.${id};
      compliant = false;
    }
    else if cfg.satisfiedExternally ? ${id}
    then {
      status = "Compliant (external evidence)";
      detail = cfg.satisfiedExternally.${id};
      compliant = true;
    }
    else if !(builtins.elem id cfg.implemented)
    then {
      status = "Not Implemented";
      detail = "This host's stig profile (${cfg.profile}) does not carry the control.";
      compliant = false;
    }
    else if cfg.requiresReboot ? ${id}
    then {
      status = "Configured (pending reboot)";
      detail = cfg.requiresReboot.${id};
      compliant = false;
    }
    else if cfg.deferredVerification ? ${id}
    then {
      status = "Compliant (VM test)";
      detail = "Runtime state, not observable in the configuration: ${cfg.deferredVerification.${id}} Proven by `moon run stig-vm-test` (checks.<system>.stig-${id}).";
      compliant = true;
    }
    else {
      status = "Compliant (configuration)";
      detail = "Declared by features/security/stig/controls/${id}.nix and asserted by its colocated suite.";
      compliant = true;
    };

  rows =
    map (id: let
      control = stig.get id;
      v = statusOf id;
    in {
      inherit id;
      inherit (v) status detail compliant;
      severity = control.severity;
      category = catOf control.severity;
      title = control.title;
      cci = control.cci;
      ruleId = control.ruleId;
      ruleVersion = control.ruleVersion;
    })
    manifest.ids;

  countWhere = pred: builtins.length (builtins.filter pred rows);

  summary = {
    inherit hostName;
    benchmark = "${stig.benchmark.title} V${stig.benchmark.version}R${stig.benchmark.release}";
    benchmarkDate = stig.benchmark.benchmarkDate;
    profile = cfg.profile;
    total = builtins.length rows;
    compliant = countWhere (r: r.compliant);
    byStatus = builtins.listToAttrs (map (s: {
        name = s;
        value = countWhere (r: r.status == s);
      }) [
        "Compliant (configuration)"
        "Compliant (VM test)"
        "Compliant (external evidence)"
        "Configured (pending reboot)"
        "Not Applicable"
        "Not Implemented"
      ]);
    catOneOpen =
      map (r: r.id)
      (builtins.filter (r: r.severity == "high" && !r.compliant) rows);
  };

  escape = s: builtins.replaceStrings ["|" "\n"] ["\\|" " "] s;

  mdRow = r: "| `${r.id}` | ${r.category} | ${escape r.title} | ${r.status} | ${builtins.concatStringsSep ", " r.cci} | ${escape r.detail} |";

  markdown = ''
    # Anduril NixOS STIG compliance report — ${hostName}

    **Benchmark:** ${summary.benchmark} (${summary.benchmarkDate})
    **Profile:** `${summary.profile}`
    **Controls:** ${toString summary.total}

    Generated from the evaluated NixOS configuration. This benchmark ships no OVAL/SCAP
    content — all ${toString summary.total} checks are manual — so no scanner can produce this.

    ## Summary

    | Status | Count | Means |
    |---|---|---|
    | Compliant (configuration) | ${toString summary.byStatus."Compliant (configuration)"} | Provable by evaluating the config; asserted by a colocated suite |
    | Compliant (VM test) | ${toString summary.byStatus."Compliant (VM test)"} | Runtime state, proven on a booted machine by `moon run stig-vm-test` |
    | Compliant (external evidence) | ${toString summary.byStatus."Compliant (external evidence)"} | Met outside the STIG module set; the Basis column cites the evidence |
    | Configured (pending reboot) | ${toString summary.byStatus."Configured (pending reboot)"} | Correct in the generation, not yet in effect on the running kernel |
    | Not Applicable | ${toString summary.byStatus."Not Applicable"} | Excluded with a written justification |
    | Not Implemented | ${toString summary.byStatus."Not Implemented"} | In the benchmark, not carried by this profile |

    **Compliant: ${toString summary.compliant} of ${toString summary.total}.**

    ${
      if summary.catOneOpen == []
      then "No CAT I control is open."
      else "**CAT I not compliant: ${builtins.concatStringsSep ", " summary.catOneOpen}.**"
    }

    ## Controls

    | Control | Severity | Requirement | Status | CCI | Basis |
    |---|---|---|---|---|---|
    ${builtins.concatStringsSep "\n" (map mdRow rows)}
  '';

  json = builtins.toJSON {
    inherit summary;
    controls = rows;
  };
in
  pkgs.runCommand "stig-report-${hostName}" {
    passthru = {inherit summary rows;};
  } ''
    mkdir -p $out
    cp ${pkgs.writeText "stig-report-${hostName}.md" markdown} $out/report.md
    cp ${pkgs.writeText "stig-report-${hostName}.json" json} $out/report.json
    echo "${hostName}: ${toString summary.compliant}/${toString summary.total} compliant" > $out/summary.txt
  ''

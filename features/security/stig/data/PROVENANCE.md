# Provenance — Anduril NixOS STIG V1R3

This directory holds the **single upstream** for the STIG baseline in
`features/security/stig/`. Everything else under `stig/` is derived from it.

## Vendored file

| | |
|---|---|
| Path | `Anduril_NixOS_STIG-V1R3.xccdf.xml` |
| Size | 361524 bytes |
| sha256 | `722d29bd47377ef6272a24bcdfd2610d4b3c5facc0c050815de8ea74fb5c9dac` |
| Original name | `U_Anduril_NixOS_V1R3_Manual_STIG/U_Anduril_NixOS_STIG_V1R3_Manual-xccdf.xml` |
| Renamed | Only the filename; content is byte-identical to the DISA download (`cmp` verified) |

## Source

| | |
|---|---|
| Download | <https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_Anduril_NixOS_V1R3_STIG.zip> |
| Zip sha256 | `683507e3972e5842196523302bbdddd9930dcd8b6b56e355d95beeba45ae01db` |
| Zip size | 2138255 bytes |
| Retrieved | 2026-10-28 |
| Publisher | DISA (Defense Information Systems Agency); content authored by Anduril Industries |
| Title | Anduril NixOS Security Technical Implementation Guide |
| Version / Release | V1R3 — `Release: 3 Benchmark Date: 30 Sep 2026` |
| Catalogue entries | [NIST NCP checklist 1260](https://ncp.nist.gov/checklist/1260) · [cyber.trackr.live](https://cyber.trackr.live/stig/Anduril_NixOS/1/3) |

The zip also contained `U_Anduril_NixOS_V1R3_Overview.pdf`,
`U_Anduril_NixOS_V1R3_Revision_History.pdf`, `U_Anduril_NixOS_STIG_V1_Release_Memo.pdf`,
`U_Readme_SRG_and_STIG.pdf`, `STIG_unclass.xsl` and a DoW/DISA logo JPEG. Only the XCCDF is
vendored — the rest is documentation available at the same URL and adds ~2 MB of binaries for
no build value.

## Verified properties

Checked against the vendored file at retrieval time; these are the facts
`lib/parse-xccdf.nix` and `lib/manifest.nix` assert in Nix.

| Property | Value |
|---|---|
| Rule count | 103 |
| Severity split | 11 high (CAT I) · 91 medium (CAT II) · 1 low (CAT III) |
| Control id range | `V-268078` … `V-268181` |
| Consent banner wording | "Standard Mandatory **DoW** Notice and Consent Banner" ×12; zero occurrences of "Department of Defense" |
| Check content | **Manual for all 103 rules** — every `<check>` carries `check-content-ref name="M" href="Anduril_NixOS_STIG.xml"` |

Two consequences worth keeping in front of anyone reading this directory:

1. **There is no OVAL/SCAP content for this STIG.** The archive is named
   `..._Manual_STIG`, and all 103 checks are manual. No SCC or OpenSCAP scanner can grade a
   host against this baseline — which is why `tests/vm/` and `lib/report.nix` exist.
2. **V1R3 renamed the banner to "Department of War."** Any implementation still carrying V1R1
   banner text fails V-268082 / V-268083 / V-268084 silently. Do not copy banner strings from
   older third-party modules.

## Licensing

US Government work product, distributed publicly and without charge from the DoD Cyber
Exchange. Treated here as redistributable. Not independently legally reviewed — confirm before
publishing this directory outside the repo.

## Updating to a new release

Do **not** hand-edit the XCCDF. The upgrade path is deliberately a build failure:

1. Download the new `U_Anduril_NixOS_V1R<n>_STIG.zip`, extract the `*-Manual-xccdf.xml`.
2. Add it alongside as `Anduril_NixOS_STIG-V1R<n>.xccdf.xml`; update this file with the new
   sizes, hashes and verified properties.
3. Point `lib/parse-xccdf.nix` at the new file. `lib/manifest.nix` will now mismatch the parsed
   control set and `nix eval` will **throw** until every added control has a module, a suite
   and a VM test, and every removed control is deleted.
4. Re-check the banner wording — DISA has changed it once already.

That throw is the feature. It is what makes "hoping nothing drifts" unnecessary.

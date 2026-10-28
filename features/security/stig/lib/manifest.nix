# The control ids this repo acknowledges from Anduril NixOS STIG V1R3.
#
# Hand-committed on purpose. The list below is the human-acknowledged control set; the parsed
# XCCDF is upstream's. Comparing them is the drift guard: dropping in a new release changes the
# parsed set, this file does not, and eval throws until someone works through the delta.
#
# Generated once with `bin/stig-xccdf-to-json` + `builtins.attrNames`. Do not regenerate it
# mechanically to silence a failure — that defeats the entire mechanism.
let
  stig = import ./parse-xccdf.nix;

  acknowledged = [
    "V-268078"
    "V-268079"
    "V-268080"
    "V-268081"
    "V-268082"
    "V-268083"
    "V-268084"
    "V-268085"
    "V-268086"
    "V-268087"
    "V-268088"
    "V-268089"
    "V-268090"
    "V-268091"
    "V-268092"
    "V-268093"
    "V-268094"
    "V-268095"
    "V-268096"
    "V-268097"
    "V-268098"
    "V-268099"
    "V-268100"
    "V-268101"
    "V-268102"
    "V-268103"
    "V-268104"
    "V-268105"
    "V-268106"
    "V-268107"
    "V-268108"
    "V-268109"
    "V-268110"
    "V-268111"
    "V-268112"
    "V-268113"
    "V-268114"
    "V-268115"
    "V-268116"
    "V-268117"
    "V-268118"
    "V-268119"
    "V-268120"
    "V-268121"
    "V-268122"
    "V-268123"
    "V-268124"
    "V-268125"
    "V-268126"
    "V-268127"
    "V-268128"
    "V-268129"
    "V-268130"
    "V-268131"
    "V-268132"
    "V-268133"
    "V-268134"
    "V-268135"
    "V-268136"
    "V-268137"
    "V-268138"
    "V-268139"
    "V-268140"
    "V-268141"
    "V-268142"
    "V-268143"
    "V-268144"
    "V-268145"
    "V-268146"
    "V-268147"
    "V-268148"
    "V-268149"
    "V-268150"
    "V-268151"
    "V-268152"
    "V-268153"
    "V-268154"
    "V-268155"
    "V-268156"
    "V-268157"
    "V-268158"
    "V-268159"
    "V-268160"
    "V-268161"
    "V-268163"
    "V-268164"
    "V-268165"
    "V-268166"
    "V-268167"
    "V-268168"
    "V-268169"
    "V-268170"
    "V-268171"
    "V-268172"
    "V-268173"
    "V-268174"
    "V-268175"
    "V-268176"
    "V-268177"
    "V-268178"
    "V-268179"
    "V-268180"
    "V-268181"
  ];

  parsed = stig.ids;

  missing = builtins.filter (id: !builtins.elem id acknowledged) parsed;
  extra = builtins.filter (id: !builtins.elem id parsed) acknowledged;

  fmt = label: xs:
    if xs == []
    then ""
    else "  ${label}: ${builtins.concatStringsSep " " xs}\n";
in
  if missing != [] || extra != []
  then
    builtins.throw ''
      features/security/stig: acknowledged control set has drifted from the vendored benchmark
      (${stig.benchmark.title} V${stig.benchmark.version}R${stig.benchmark.release}, ${stig.benchmark.benchmarkDate}).
      ${fmt "in the STIG but not acknowledged here" missing}${fmt "acknowledged here but absent from the STIG" extra}
      Work through the delta: a new control needs an entry in this list, a module in
      controls/, a colocated suite, and a VM test in tests/vm/. A removed control needs all
      four deleted. See data/PROVENANCE.md for the release procedure.
    ''
  else {
    ids = acknowledged;
    count = builtins.length acknowledged;
    release = "V${stig.benchmark.version}R${stig.benchmark.release}";
  }

# Assay: features/nixos/etc-overlay/carry.nix, the two copies that move a host's stateful
# /etc across the setup-etc.pl <-> overlay boundary. These claims pin what each script
# skips and how it copies; what they do to a real /etc is ./test-live-switch.nix's.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (nixos) lib;

  carry = import ./carry.nix {inherit pkgs lib;};
  has = script: s: lib.hasInfix s script.text;
in
  assay.suite "etc-overlay-carry" {
    # setup-etc.pl's bookkeeping and its link to the generation's tree never move.
    inSkipsSetupEtcOwn = assay.eq (has carry.carryIn ".clean | static | .rw-etc*) continue") true;
    inSkipsStaticLinks = assay.eq (has carry.carryIn "/etc/static/*) continue") true;
    inSkipsSetupEtcCopies = assay.eq (has carry.carryIn "grep -qxF -- \"$p\" .clean") true;
    inSkipsWhatTheGenerationDeclares = assay.eq (has carry.carryIn "if [ -e \"$lower/$p\" ] || [ -L \"$lower/$p\" ]; then continue; fi") true;
    inNeverOverwrites = assay.eq (has carry.carryIn "if [ -e \"$upper/$p\" ] || [ -L \"$upper/$p\" ]; then continue; fi") true;
    inKeepsAttributes = assay.eq (has carry.carryIn "cp -a --parents") true;
    inRecordsWhatItCarried = assay.eq (has carry.carryIn "printf '%s\\0' \"$p\" >> \"$list\"") true;
    inStaysOnOneFilesystem = assay.eq (has carry.carryIn "find . -xdev") true;

    outOverwrites = assay.eq (has carry.carryOut "cp -a --parents --remove-destination") true;
    outAppliesWhiteouts = assay.eq (has carry.carryOut "= 0:0 ]") true;
    outAppliesDeletedCarriedFiles = assay.eq (has carry.carryOut "done < \"$list\"") true;
    outSkipsSetupEtcOwn = assay.eq (has carry.carryOut ".clean | static) continue") true;

    # The initrd gets these explicitly: a script's references are not followed there.
    toolsForTheInitrd = assay.eq (map lib.getName carry.tools) ["coreutils" "findutils" "gnugrep"];
  }

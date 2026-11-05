# Colocated suite: `cheatsheet` as a router, not a curl.
#
# The regression this guards is the one the feature started as: a wrapper whose entire body was
# `curl "https://cheat.sh/$@"`, so that `cheatsheet tar` could not answer on a host with no
# network. What matters now is the ORDER — the local tldr page cache first, cheat.sh only behind
# an explicit `--web` — and that nothing reaches the network on the default path.
#
# The derivation is stubbed rather than built so the suite stays an evaluation: `name` is still
# what lands on the system path, and `text` is the script verbatim.
let
  assay = import ./../../../common/assay/default.nix;

  pkgs = {
    writeShellApplication = args: args;
    tealdeer = "/nix/store/stub-tealdeer";
    curl = "/nix/store/stub-curl";
  };

  mod = import ./default.nix {inherit pkgs;};
  wrapper = builtins.head mod.environment.systemPackages;
  script = wrapper.text;

  nixpkgsLib = (import <nixpkgs> {}).lib;
  has = needle: nixpkgsLib.hasInfix needle script;

  # Shell comments here explain what the script does NOT do as often as what it does — the
  # `--web` branch's comment names a cheat.sh URL to contrast with — so claims about where the
  # script reaches have to look at the commands and not the prose above them.
  code =
    builtins.concatStringsSep "\n"
    (builtins.filter
      (l: !(nixpkgsLib.hasPrefix "#" (nixpkgsLib.trim l)))
      (nixpkgsLib.splitString "\n" script));

  # The flag-less path: everything from the end of the `case` to the end of the script.
  defaultPath = builtins.elemAt (nixpkgsLib.splitString "esac" code) 1;
in
  assay.suite "cheatsheet" {
    systemPackages = assay.eq (map (p: p.name) mod.environment.systemPackages) ["cheatsheet"];

    # ---------------------------------------------------------------------------
    # Offline first
    # ---------------------------------------------------------------------------
    #
    # The default path is tldr and only tldr. features/cli/tealdeer has already put the pages
    # on disk and turned auto_update off, so this opens no socket.
    defaultPathAsksTldr = assay.eq (nixpkgsLib.hasInfix "tldr \"$@\"" defaultPath) true;
    defaultPathNeverFetches =
      assay.eq
      (nixpkgsLib.any (needle: nixpkgsLib.hasInfix needle defaultPath) [
        "curl"
        "wget"
        "https://"
      ])
      false;

    # ---------------------------------------------------------------------------
    # cheat.sh, only when asked for by name
    # ---------------------------------------------------------------------------
    webIsOptIn = assay.eq (has "--web)") true;
    webIsTheOnlyPathToCheatSh =
      assay.eq (builtins.length (nixpkgsLib.splitString "cheat.sh/" code)) 2;
    # The old one-liner interpolated "$@" straight into the URL; cheat.sh wants its topic as a
    # path, so anything but a single word produced a broken request.
    webJoinsItsTopicWithSlashes = assay.eq (has "tr ' ' '/'") true;
    # A silent failure that prints cheat.sh's HTML error page is worse than no answer.
    webFailsLoudly = assay.eq (has "curl --fail --silent --show-error") true;

    # ---------------------------------------------------------------------------
    # The miss message
    # ---------------------------------------------------------------------------
    #
    # A tldr miss is where someone is most likely to want this fleet's own answer, and navi is
    # where that lives. Naming it here is the only reason the wrapper is worth keeping at all.
    missNamesNavi = assay.eq (has "navi --query") true;
    missNamesTheWebEscapeHatch = assay.eq (has "cheatsheet --web") true;
    missNamesWhatWasMissing = assay.eq (has "no local tldr page for") true;
    # To stderr: a miss must not look like a page when the output is piped somewhere.
    missGoesToStderr = assay.eq (has "no local tldr page for '$*'.\" >&2") true;

    # ---------------------------------------------------------------------------
    # Housekeeping
    # ---------------------------------------------------------------------------
    #
    # writeShellApplication runs shellcheck over the body and sets errexit/nounset/pipefail,
    # which the hand-rolled `echo '#!/usr/bin/env bash' > $out/bin/...` derivation did not.
    declaresItsRuntimeInputs = assay.eq (wrapper ? runtimeInputs) true;
    # `buildInputs = [pkgs.dust]` was copy-pasted in from features/cli/du and the script never
    # used it. What the script does use is declared.
    declaresWhatItRuns = assay.eq wrapper.runtimeInputs ["/nix/store/stub-tealdeer" "/nix/store/stub-curl"];
    hasAUsage = assay.eq (has "Usage: cheatsheet") true;
  }

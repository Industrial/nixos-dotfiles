# Colocated suite: the console helpers shared by the PAM VM tests.
let
  assay = import ./../../../../../common/assay/default.nix;
  inherit ((import <nixpkgs> {})) lib;
  helpers = import ./console.nix;
  defines = name: lib.hasInfix "\ndef ${name}(" helpers;
in
  assay.suite "stig-vm-console" {
    isPythonSource = assay.eq (builtins.isString helpers && lib.hasPrefix "import re\n" helpers) true;
    definesWhatTheTestsCall =
      assay.eq (map defines ["screen_ends_with" "type_logon" "refused" "accepted" "failures"]) [true true true true true];
    # Spliced at column 0 of a test script: a helper indented by the Nix string would be a
    # Python syntax error only seen once a VM has been built.
    startsAtColumnZero = assay.eq (lib.hasInfix "\n  def " helpers) false;
    # Typed at a real getty, and judged by the end of the screen (the banner scrolls it).
    typesAtTheConsole = assay.eq (lib.hasInfix "machine.send_chars(password" helpers) true;
    readsTheEndOfTheScreen = assay.eq (lib.hasInfix "get_tty_text(tty).rstrip().endswith(suffix)" helpers) true;
    # A refusal is only a refusal if no session appeared on that console.
    refusalChecksForNoSession = assay.eq (lib.hasInfix "machine.fail(f\"pgrep -t tty{tty} -u {user}\")" helpers) true;
    # The tally is read the way an administrator reads it.
    tallyComesFromFaillock = assay.eq (lib.hasInfix "faillock --user {user}" helpers) true;
  }

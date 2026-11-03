# Assay: fleet remote desktop relay (mimir).
#
# The load-bearing claim is firewallStaysClosed. Tailnet reachability comes
# from features/security/tailscale marking tailscale0 trusted; flipping
# openFirewall would publish 21115-21119 on every interface instead, which
# would silently undo the "inside tailscale" requirement.
let
  assay = import ../../common/assay/default.nix;
  src = builtins.readFile ./remote-desktop-relay.nix;

  # Match against CODE, not prose — see remote-access.assay.nix for the full reasoning.
  # Here it is `noRemovedRelayIP` that needs it: the module's header explains that upstream
  # removed `relayIP`, so the word appears in the file, and the claim forbidding the setting
  # was failed by the note recording its removal.
  isCommentLine = l: builtins.match "[[:space:]]*#.*" l != null;
  code =
    builtins.concatStringsSep "\n"
    (builtins.filter (l: !isCommentLine l)
      (builtins.filter builtins.isString (builtins.split "\n" src)));
in
  assay.suite "remote-desktop-relay" {
    enablesServer = assay.eq (builtins.match ".*services\\.rustdesk-server.*" code != null) true;
    enablesSignal = assay.eq (builtins.match ".*signal = [{].*" code != null) true;
    enablesRelay = assay.eq (builtins.match ".*relay = [{].*" code != null) true;

    # Never publish the ports beyond the tailnet.
    firewallStaysClosed = assay.eq (builtins.match ".*openFirewall = false.*" code != null) true;
    noOpenFirewall = assay.eq (builtins.match ".*openFirewall = true.*" code != null) false;

    # Clients need an advertised relay endpoint; empty relayHosts makes hbbs
    # start with a bare `--relay-servers` argument.
    #
    # The brackets are matched with POSIX bracket expressions — `[[]` for a literal `[`,
    # `[]]` for a literal `]` — not with backslash escapes. builtins.match compiles POSIX
    # EXTENDED regexes, where `\[` is not a defined escape: it raises
    # `error: invalid regular expression` at eval time, which took down the whole repo-wide
    # `assay run .` (and therefore every commit, via the pre-commit hook) rather than
    # failing this one case.
    declaresRelayHost = assay.eq (builtins.match ".*relayHosts = [[]\"mimir\"[]].*" code != null) true;

    # relayIP was removed upstream in favour of signal.relayHosts.
    noRemovedRelayIP = assay.eq (builtins.match ".*relayIP.*" code != null) false;

    # The stripper must actually strip, or noRemovedRelayIP silently weakens to "not even
    # mentioned in a comment" — which is how this suite failed in the first place. Asserted
    # by length rather than by a canary string, so rewording a comment cannot disarm it.
    commentsAreStripped = assay.eq (builtins.stringLength code < builtins.stringLength src) true;

    # And the specific trap this file documents: `relayIP` is named in the header, so the
    # ban above is only meaningful because the header is not part of `code`.
    relayIPIsNamedOnlyInProse = assay.eq (builtins.match ".*relayIP.*" src != null) true;
  }

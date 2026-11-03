# Assay: fleet remote desktop client.
#
# The client feature is deliberately inert on the network: it installs the
# RustDesk binary and nothing else. Reachability is owned by
# features/security/tailscale (trustedInterfaces) and the server side lives in
# remote-desktop-relay.nix, so a port opened here would be a scope leak.
let
  assay = import ../../common/assay/default.nix;
  src = builtins.readFile ./remote-desktop.nix;

  # Match against CODE, not prose — see remote-access.assay.nix for the full reasoning.
  # This module's header documents the server side and the firewall posture it deliberately
  # does not configure, so the negative claims below would be read against their own
  # explanation. Applied here too even though it currently passes: the next comment that
  # names `services.rustdesk-server` is the one that would break it.
  isCommentLine = l: builtins.match "[[:space:]]*#.*" l != null;
  code =
    builtins.concatStringsSep "\n"
    (builtins.filter (l: !isCommentLine l)
      (builtins.filter builtins.isString (builtins.split "\n" src)));
in
  assay.suite "remote-desktop" {
    installsClient = assay.eq (builtins.match ".*rustdesk.*" code != null) true;

    # The signal/relay servers belong on mimir only, never in the all-host feature.
    noServerHere = assay.eq (builtins.match ".*services\\.rustdesk-server.*" code != null) false;

    # Must not publish ports; the tailnet trusted interface is the only path.
    noFirewallOpening = assay.eq (builtins.match ".*allowedTCPPorts.*" code != null) false;
    noOpenFirewall = assay.eq (builtins.match ".*openFirewall = true.*" code != null) false;

    # The stripper must actually strip, or the negative claims above silently weaken to
    # "not even mentioned in a comment". Asserted by length rather than by a canary string,
    # so rewording a comment cannot quietly disarm it.
    commentsAreStripped = assay.eq (builtins.stringLength code < builtins.stringLength src) true;

    # And the client must not reference the server module at all — that is mimir's import.
    noRelayReferenceInCode = assay.eq (builtins.match ".*remote-desktop-relay.*" code != null) false;
  }

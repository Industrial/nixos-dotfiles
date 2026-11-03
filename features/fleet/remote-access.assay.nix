# Assay: fleet remote access.
#
# comin itself moved to features/fleet/comin.nix and is enabled there per host
# (ADR-0002). The noCominEnable claim below is still load-bearing: activation
# semantics must not be smuggled into an access module.
let
  assay = import ../../common/assay/default.nix;
  src = builtins.readFile ./remote-access.nix;

  # Match against CODE, not prose.
  #
  # Every claim here is a source-text match, and a negative claim ("this module must not
  # mention X") is falsified by the comment that explains why X is absent. That is not
  # hypothetical: documenting that the relay half lives on mimir, by naming
  # remote-desktop-relay.nix in the header, broke `noRelayHere` — the suite forbade the
  # string, and the explanation of the ban contained it.
  #
  # Stripping comment-only lines keeps a module documentable. Positive claims read `code`
  # too, so "it is mentioned in a comment" can never stand in for "it is configured".
  isCommentLine = l: builtins.match "[[:space:]]*#.*" l != null;
  code =
    builtins.concatStringsSep "\n"
    (builtins.filter (l: !isCommentLine l)
      (builtins.filter builtins.isString (builtins.split "\n" src)));
in
  assay.suite "remote-access" {
    enablesTailscale = assay.eq (builtins.match ".*services\\.tailscale\\.enable = lib\\.mkForce true.*" code != null) true;
    importsSsh = assay.eq (builtins.match ".*network/ssh.*" code != null) true;
    importsOperatorSsh = assay.eq (builtins.match ".*operator-ssh\\.nix.*" code != null) true;

    # Fleet-wide RustDesk client rides in through this module, since every host
    # imports it. The relay half must stay out (mimir imports that directly).
    importsRemoteDesktop = assay.eq (builtins.match ".*remote-desktop\\.nix.*" code != null) true;
    noRelayHere = assay.eq (builtins.match ".*remote-desktop-relay\\.nix.*" code != null) false;
    noCominEnable = assay.eq (builtins.match ".*services\\.comin\\.enable.*" code != null) false;

    # The stripper must actually strip, or every negative claim above silently weakens to
    # "not even mentioned in a comment" — which is how this suite failed in the first place.
    # Asserted by length rather than by a canary string, so rewording a comment cannot
    # disarm it.
    commentsAreStripped = assay.eq (builtins.stringLength code < builtins.stringLength src) true;

    # And the specific trap this file documents: the relay module is named in the header, so
    # `noRelayHere` is only meaningful because the header is not part of `code`.
    relayIsNamedOnlyInProse = assay.eq (builtins.match ".*remote-desktop-relay.*" src != null) true;
  }

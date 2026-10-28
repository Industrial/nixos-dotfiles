# V-268135 (CAT II) — NixOS must uniquely identify and must authenticate organizational users
# (or processes acting on behalf of organizational users).
#
# Fix text is remediation prose, not configuration: "editing the file /etc/passwd and provide
# each interactive user account that has a duplicate UID with a unique UID".
#
# On NixOS /etc/passwd is generated, so hand-editing it is both impossible and pointless. But
# the underlying property — no two interactive accounts share a UID — IS expressible, and it
# is exactly the kind of thing a declarative system should assert rather than audit after the
# fact. So this control is an eval-time assertion over the declared users.
#
# Only normal (interactive) users are considered. System users legitimately share no UIDs
# either, but the requirement is explicitly about interactive accounts, and nixpkgs allocates
# system UIDs itself.
#
# `full` profile, though it is non-disruptive in practice — it changes nothing unless the
# configuration is already wrong, in which case it should fail.
{
  config,
  lib,
  ...
}: let
  interactive = lib.filterAttrs (_: u: u.isNormalUser && u.uid != null) config.users.users;
  uids = lib.mapAttrsToList (_: u: u.uid) interactive;
  duplicated = lib.unique (lib.filter (uid: lib.count (x: x == uid) uids > 1) uids);
  offenders =
    lib.mapAttrsToList (name: u: "${name}=${toString u.uid}")
    (lib.filterAttrs (_: u: lib.elem u.uid duplicated) interactive);
in {
  assertions = [
    {
      assertion = duplicated == [];
      message = ''
        V-268135: interactive accounts share a UID, so they cannot be uniquely identified and
        audit records cannot be attributed to a person: ${lib.concatStringsSep ", " offenders}.

        Give each interactive account its own users.users.<name>.uid.
      '';
    }
  ];
}

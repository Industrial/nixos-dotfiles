# V-268090 (CAT II) — The NixOS audit package must be installed.
#
# VERIFY-ONLY. Emits nothing, deliberately.
#
# The fix text says to add `audit` to environment.systemPackages. On current nixpkgs that is
# redundant: nixos/modules/security/audit.nix already does
#
#   environment.systemPackages = [ cfg.package ];
#
# inside `config = lib.mkIf (cfg.enable == "lock" || cfg.enable)`. So V-268080 enabling
# `security.audit.enable` installs the package as a side effect. Declaring it again would put
# a second reference to the same derivation in systemPackages for no benefit.
#
# The coverage claim is checked in the colocated suite against the real nixpkgs module rather
# than asserted in a comment.
{...}: {
  # Intentionally empty — see above and ./V-268090.assay.nix.
}

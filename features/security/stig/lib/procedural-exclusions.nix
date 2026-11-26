# The three controls in the benchmark that have no configuration to carry, on any host.
#
# Held once and read by every profile that accounts for all 103 controls (profiles/full.nix,
# profiles/test-host.nix), so the justification an assessor reads is the same text wherever
# the control is excluded. Data only: an attrset of control id to written reason, in the shape
# `security.stig.exclude` takes.
#
# V-268079 was classified `n-a` in docs/security/stig-triage.md from the start but was never
# declared anywhere, so it fell through every count. full.assay.nix's completeness assertion
# is what caught it — 102 of 103 accounted for — which is the whole reason that assertion
# compares against the manifest rather than trusting a tally.
{
  # Policy, not configuration. The requirement is that emergency and temporary accounts
  # expire within 72 hours; this fleet creates none. There is no option to set, only a
  # commitment to re-assert this justification if such an account is ever added.
  "V-268079" = "No emergency or temporary accounts exist on any host in this fleet, so there is nothing to apply an expiry to. Must be re-asserted if one is ever created — an account with no expiry would then be an undetected finding.";

  # Procedural. The requirement is that private keys are protected by a passphrase, which
  # is a property of keys users generate, not of system configuration. The fix text is a
  # command to run (`ssh-keygen -n [passphrase]`) and it is also wrong: -n is not the
  # passphrase flag, -N is. Nothing here can assert what passphrase a user chose.
  "V-268125" = "Procedural: private-key passphrase protection is a property of user-generated keys, not of system configuration. The fix text is a command for an operator to run, and names the wrong ssh-keygen flag (-n rather than -N). No configuration can assert it.";

  # Procedural. "Run a supported release of the operating system" is satisfied by this
  # repo's nixpkgs pin and its update policy, not by an option.
  "V-268180" = "Procedural: satisfied by the flake's nixpkgs pin and update policy rather than by any NixOS option.";
}

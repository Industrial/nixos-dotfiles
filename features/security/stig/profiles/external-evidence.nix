# STIG controls met by something other than a control module, with the evidence.
#
# Imported by profiles/base.nix, so every host carries it — which is the point. The facts
# recorded here are properties of the FLEET (its disk layout), not of whichever baseline a
# given host happens to import, and they do not stop being true on a host that carries no
# controls.
#
# This used to live inside profiles/base-safe.nix. ADR-0004 narrowed that profile to mimir
# alone, which would have silently withdrawn a true CAT I claim from the other three hosts:
# their roots are LUKS-encrypted exactly as mimir's is, but their reports started saying
# "Not Implemented". Splitting the evidence out of the profile is what keeps the two
# independent — a host can carry no controls and still report what is actually true of it.
#
# One file, one declaration site. profiles/full.assay.nix reads this file directly when it
# proves all 103 controls are accounted for, so the roster and the completeness proof cannot
# disagree.
{...}: {
  security.stig.satisfiedExternally = {
    # CAT I — "protect the confidentiality and integrity of all information at rest".
    #
    # Genuinely satisfied on this fleet, but by the DISK LAYOUT rather than by any NixOS
    # option: every hosts/<name>/disko.nix puts the root filesystem inside a LUKS container
    # with no keyfile in the store, and each hosts/<name>/disko.assay.nix asserts exactly
    # that. There is nothing for a control module to declare.
    #
    # Reporting it as "Not Implemented" would understate a CAT I control that is in fact met,
    # which misleads as badly as overstating one. The citation names files that assert the
    # property, so the claim is checkable rather than asserted.
    "V-268144" = "The root filesystem is inside a LUKS container with no keyfile in the Nix store, declared per host in hosts/<name>/disko.nix (type = \"luks\", name = \"cryptroot\") and asserted by hosts/<name>/disko.assay.nix for all four hosts. The ESP cannot be encrypted, so it is mounted umask=0077 instead.";
  };
}

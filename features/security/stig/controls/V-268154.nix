# V-268154 (CAT I) — NixOS must prevent the installation of patches, service packs, device
# drivers, or operating system components without verification they have been digitally signed
# using a certificate that is recognized and approved by the organization.
#
# Fix text: nix.settings.require-sigs = true;
#
# This is already the nixpkgs default, which is why the control costs nothing. It is declared
# anyway rather than relied upon: `require-sigs = false` is a one-line change somewhere else in
# a config, and this being a CAT I control means the baseline should state it explicitly so the
# report can prove it rather than infer it from a default.
#
# Note what the control actually buys on NixOS: every substituted store path must carry a
# signature from a trusted key. That is a stronger property than the requirement's
# patches-and-drivers framing, because it covers the entire system closure.
{...}: {
  nix.settings.require-sigs = true;
}

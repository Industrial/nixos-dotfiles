# V-268179 (CAT II) — For PKI-based authentication, NixOS must implement a local cache of
# revocation data to support path discovery and validation in case of the inability to access
# revocation information via the network.
#
# Fix text sets `security.pam.p11.enable = true` and a cert_policy of
# "ca,signature,ocsp_on, crl_auto".
#
# `crl_auto` is the part that satisfies this requirement: it caches CRLs locally so validation
# still works when the network does not. `ocsp_on` is the online check, and `ca` and
# `signature` are the path-construction requirements V-268124 covers.
#
# nixpkgs' security.pam.p11 module does not expose cert_policy as a typed option, so the
# policy goes into the p11 configuration file the module reads. The enable half is shared with
# V-268177, and identical bool definitions merge.
#
# `full` profile, and only meaningful with the PKI from V-268124 in place.
{...}: {
  security.pam.p11.enable = true;

  # cert_policy lives in pam_p11's own config rather than a NixOS option.
  environment.etc."pam_p11/cert_policy".text = "ca,signature,ocsp_on,crl_auto\n";
}

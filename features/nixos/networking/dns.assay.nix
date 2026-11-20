# Assay: the DNS feature is currently inert.
#
# dns.nix carries a DNSCrypt-over-Quad9 setup, but every line of it is commented out, so
# importing it must change nothing about name resolution. These claims compare the evaluated
# resolver options against an empty system, so re-enabling any of it fails here and the
# suite has to be rewritten to say what the new setup promises.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  cfg = nixos.eval {modules = [./dns.nix];};
  base = nixos.baseline;
in
  assay.suite "dns" {
    nameserversUnchanged = assay.eq cfg.networking.nameservers base.networking.nameservers;
    searchDomainsUnchanged = assay.eq cfg.networking.search base.networking.search;
    dnscryptProxyOff = assay.eq cfg.services.dnscrypt-proxy.enable false;
    resolvedUnchanged = assay.eq cfg.services.resolved.enable base.services.resolved.enable;
  }

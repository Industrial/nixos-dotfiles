# Assay: NFS server for fleet bulk storage (mimir /data).
#
# The export list is the security boundary of this feature, so it is parsed out of the
# evaluated services.nfs.server.exports (generated /etc/exports text -- the artifact) and
# asserted exactly: which path, which clients, which options. The firewall claims read the
# evaluated networking.firewall options: NFS is reachable over tailscale0 only.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  cfg = nixos.eval {modules = [./default.nix];};
  nfs = cfg.services.nfs.server;
  exportLines = builtins.filter (l: l != "") (map lib.trim (lib.splitString "\n" nfs.exports));
  # "/path client(opts) client(opts) ..."
  parseLine = l: let
    words = builtins.filter (w: builtins.isString w && w != "") (builtins.split "[[:space:]]+" l);
  in {
    path = builtins.head words;
    clients = map (w: let
      m = builtins.match "([^(]+)\\(([^)]*)\\)" w;
    in {
      host = builtins.elemAt m 0;
      options = lib.splitString "," (builtins.elemAt m 1);
    }) (builtins.tail words);
  };
  exports = map parseLine exportLines;
  clients = builtins.concatMap (e: e.clients) exports;
  allOptions = lib.unique (builtins.concatMap (c: c.options) clients);
  tailscalePorts = cfg.networking.firewall.interfaces.tailscale0.allowedTCPPorts;
in
  assay.suite "nfs-server" {
    enablesServer = assay.eq nfs.enable true;

    exportsOnlyData = assay.eq (map (e: e.path) exports) ["/data"];
    # drakkar and huginn by tailnet address, each a single /32 -- no subnets, no wildcards.
    exportsToTheNfsClientsOnly =
      assay.eq (map (c: c.host) clients) ["100.69.213.35/32" "100.70.136.13/32"];
    everyClientIsATailnetHost =
      assay.eq (builtins.all (c: builtins.match "100\\.[0-9]+\\.[0-9]+\\.[0-9]+/32" c.host != null) clients) true;
    sameOptionsForEveryClient =
      assay.eq (lib.unique (map (c: c.options) clients)) [["rw" "sync" "no_subtree_check" "sec=sys"]];
    # root on a client stays squashed (the NFS default); nothing opts out of it.
    neverDisablesRootSquash =
      assay.eq (lib.intersectLists allOptions ["no_root_squash" "no_all_squash" "insecure"]) [];

    # rpcbind, nfsd, mountd: tailscale0 only.
    tailscaleFirewall = assay.eq tailscalePorts [111 2049 20048];
    noGlobalTCPPorts = assay.eq cfg.networking.firewall.allowedTCPPorts nixos.baseline.networking.firewall.allowedTCPPorts;
    noGlobalUDPPorts = assay.eq cfg.networking.firewall.allowedUDPPorts nixos.baseline.networking.firewall.allowedUDPPorts;
    onlyTailscaleInterfaceOpened = assay.eq (builtins.attrNames cfg.networking.firewall.interfaces) ["tailscale0"];
  }

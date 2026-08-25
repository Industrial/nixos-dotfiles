# Jackett provides API/torznab support for your torrent trackers. Port = 9117.
{...}: {
  services.jackett = {
    enable = true;
    port = 9117;
    # All state (ServerConfig.json + per-indexer JSONs) on the NFS volume.
    dataDir = "/data/services/jackett";
    # Fleet convention: services share the 'data' group for NFS access.
    group = "data";
  };
}

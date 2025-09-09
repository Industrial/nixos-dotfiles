{
  config,
  lib,
  pkgs,
  ...
}: {
  # Loki log aggregation
  services = {
    loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_port = 3100;
          grpc_listen_port = 9096;
        };
        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore = {
                store = "inmemory";
              };
              replication_factor = 1;
            };
            final_sleep = "0s";
          };
          chunk_idle_period = "5m";
          chunk_retain_period = "30s";
        };
        schema_config = {
          configs = [
            {
              from = "2020-10-24";
              store = "boltdb-shipper";
              object_store = "filesystem";
              schema = "v11";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };
        storage_config = {
          boltdb_shipper = {
            active_index_directory = "/var/lib/loki/boltdb-shipper-active";
            cache_location = "/var/lib/loki/boltdb-shipper-cache";
            cache_ttl = "24h";
          };
          filesystem = {
            directory = "/var/lib/loki/chunks";
          };
        };
        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };
        chunk_store_config = {};
        table_manager = {
          retention_deletes_enabled = false;
          retention_period = "0s";
        };
        compactor = {
          working_directory = "/var/lib/loki/compactor";
          compaction_interval = "10m";
          retention_enabled = true;
          retention_delete_delay = "2h";
          retention_delete_worker_count = 150;
        };
      };
    };
  };

  # Create Loki data directory
  systemd = {
    tmpfiles = {
      rules = [
        "d /var/lib/loki 0755 loki loki - -"
        "d /var/lib/loki/boltdb-shipper-active 0755 loki loki - -"
        "d /var/lib/loki/boltdb-shipper-cache 0755 loki loki - -"
        "d /var/lib/loki/chunks 0755 loki loki - -"
        "d /var/lib/loki/compactor 0755 loki loki - -"
      ];
    };
  };

  # Create loki user
  users = {
    users = {
      loki = {
        isSystemUser = true;
        group = "loki";
        home = "/var/lib/loki";
        createHome = true;
      };
    };
    groups = {
      loki = {};
    };
  };
}
